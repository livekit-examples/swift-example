/*
 * Copyright 2025 LiveKit
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Accelerate
@preconcurrency import AVFAudio
import Foundation
import LiveKit

internal import LiveKitFFI

/// Extension to work with LKAudioBuffer for resampling
extension LKAudioBuffer {
    /// Pass LKAudioBuffer to a closure with a temporary Int16 buffer
    /// LKAudioBuffer.rawBuffer contains Int16 values stored as Float (NOT normalized -1.0 to 1.0)
    /// The values are in the range of Int16.min to Int16.max stored in Float variables
    /// Uses Accelerate framework for vectorized conversion (much faster than loop)
    func withInt16Buffer<T>(channel: Int = 0, _ body: (UnsafeBufferPointer<Int16>) throws -> T) rethrows -> T {
        let floatBuffer = rawBuffer(forChannel: channel)

        // Use temporary allocation to avoid array overhead
        return try withUnsafeTemporaryAllocation(of: Int16.self, capacity: frames) { tempBuffer in
            // Vectorized Float to Int16 conversion using Accelerate
            // This is much faster than a loop for large buffers
            var count = vDSP_Length(frames)
            vDSP_vfix16(floatBuffer, 1, tempBuffer.baseAddress!, 1, count)

            // Call the closure with the Int16 buffer
            return try body(UnsafeBufferPointer(tempBuffer))
        }
    }
}

/// AudioCustomProcessingDelegate that resamples audio using Rust resampler and plays it back
/// The resampled audio replaces the original buffer (sent to WebRTC) and is also played back locally
final class ResamplerAudioProcessor: NSObject, AudioCustomProcessingDelegate, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    // Thread-safe access to resampler
    private let resamplerQueue = DispatchQueue(label: "com.livekit.resampler", qos: .userInitiated)
    private var resampler: LiveKitFFI.Resampler?
    private var resamplerSettings: LiveKitFFI.ResamplerSettings?
    private var outputFormat: AVAudioFormat?
    private var outputConverter: AVAudioConverter?

    private let targetOutputRate: Double = 48000.0 // WebRTC standard rate

    // Gain control to prevent overdriven audio
    private let gain: Float = 0.95 // Slightly reduce gain to prevent clipping

    // Thread-safe access to initialization state
    private var sampleRate: Int = 0
    private var numChannels: Int = 0
    private var isInitialized: Bool = false

    override init() {
        super.init()
        engine.attach(playerNode)
    }

    deinit {
        stop()
    }

    /// Start the audio engine for playback
    func start() async throws {
        print("[ResamplerAudioProcessor] Starting audio engine...")

        let format = engine.outputNode.outputFormat(forBus: 0)
        outputFormat = format

        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        try engine.start()
        print("[ResamplerAudioProcessor] Audio engine started with format: \(format)")
    }

    /// Stop the audio engine
    func stop() {
        print("[ResamplerAudioProcessor] Stopping audio engine...")
        playerNode.stop()
        engine.stop()
        outputConverter = nil

        // Clear resampler on the queue to ensure thread safety
        resamplerQueue.sync {
            resampler = nil
            resamplerSettings = nil
        }
        print("[ResamplerAudioProcessor] Audio engine stopped")
    }

    // MARK: - AudioCustomProcessingDelegate

    func audioProcessingInitialize(sampleRate sampleRateHz: Int, channels: Int) {
        // Store values on the queue for thread safety
        resamplerQueue.sync {
            self.sampleRate = sampleRateHz
            self.numChannels = channels
            self.isInitialized = true
            // Reset resampler since settings changed
            self.resampler = nil
            self.resamplerSettings = nil
        }
        print("[ResamplerAudioProcessor] ✅ audioProcessingInitialize called: \(sampleRateHz)Hz, \(channels) channels")
    }

    func audioProcessingProcess(audioBuffer: LKAudioBuffer) {
        guard engine.isRunning else { return }

        // Serialize access to resampler to prevent concurrent access
        resamplerQueue.sync {
            // If not initialized yet, try to infer from AVAudioSession or use buffer info
            var currentSampleRate = sampleRate
            var currentChannels = numChannels

            if !isInitialized || sampleRate == 0 || numChannels == 0 {
                // Use actual buffer channels
                currentChannels = Int(audioBuffer.channels)

                // Get sample rate - use AVAudioSession on iOS/tvOS/watchOS, default on macOS
                #if os(iOS) || os(tvOS) || os(watchOS)
                let audioSession = AVAudioSession.sharedInstance()
                currentSampleRate = Int(audioSession.sampleRate)
                #elseif os(macOS)
                // macOS: Use default/common sample rate (48000 is WebRTC standard)
                currentSampleRate = 48000
                #else
                // Other platforms: Use default
                currentSampleRate = 48000
                #endif

                if currentSampleRate > 0, currentChannels > 0 {
                    print("[ResamplerAudioProcessor] ⚠️ Using inferred values (audioProcessingInitialize not called): sampleRate=\(currentSampleRate), channels=\(currentChannels)")
                    // Store these as our current values
                    self.sampleRate = currentSampleRate
                    self.numChannels = currentChannels
                    self.isInitialized = true
                } else {
                    print("[ResamplerAudioProcessor] ❌ Cannot infer sample rate/channels. sampleRate=\(currentSampleRate), channels=\(currentChannels), bufferChannels=\(audioBuffer.channels)")
                    return
                }
            }

            // Validate buffer has expected channels (sanity check)
            if audioBuffer.channels != currentChannels {
                print("[ResamplerAudioProcessor] Channel mismatch: buffer has \(audioBuffer.channels), expected \(currentChannels)")
                // Update to match buffer if close
                if abs(Int(audioBuffer.channels) - currentChannels) <= 1 {
                    currentChannels = Int(audioBuffer.channels)
                    self.numChannels = currentChannels
                } else {
                    return
                }
            }

            do {
                // Initialize resampler if needed
                try initializeResamplerIfNeeded(inputRate: Double(currentSampleRate), numChannels: UInt32(currentChannels))

                guard let resampler else {
                    print("[ResamplerAudioProcessor] Resampler not initialized")
                    return
                }

                // Only support mono (1 channel) - multi-channel not supported
                guard currentChannels == 1 else {
                    fatalError("[ResamplerAudioProcessor] Multi-channel audio (\(currentChannels) channels) is not supported. Only mono (1 channel) is supported.")
                }

                // Convert Float buffer to Int16 and pass to resampler (no array allocation)
                let resampledInt16: [Int16] = try audioBuffer.withInt16Buffer(channel: 0) { int16Buffer in
                    let nativeBuffer = LiveKitFFI.NativeAudioBuffer(
                        ptr: UInt64(UInt(bitPattern: int16Buffer.baseAddress)),
                        len: UInt64(int16Buffer.count)
                    )
                    // Push audio data to resampler and get resampled output
                    return try resampler.push(input: nativeBuffer)
                }

                print("[ResamplerAudioProcessor] Resampled \(audioBuffer.frames) frames to \(resampledInt16.count) frames")

                // Convert resampled Int16 back to normalized Float32 and write to output buffer
                let outputFrameCount = resampledInt16.count
                if outputFrameCount != audioBuffer.frames {
                    print("[ResamplerAudioProcessor] Frame count mismatch: resampler output=\(outputFrameCount), buffer=\(audioBuffer.frames)")
                }

                let actualFrameCount = min(outputFrameCount, audioBuffer.frames)
                let outputChannelBuffer = audioBuffer.rawBuffer(forChannel: 0)

                // Convert Int16 back to Float (values stay in Int16 range, NOT normalized)
                // LKAudioBuffer stores Int16 values as Float (-32768 to 32767)
                for frame in 0 ..< actualFrameCount {
                    if frame < resampledInt16.count {
                        let int16Value = resampledInt16[frame]
                        // Apply gain and store as Float (keeping Int16 value range)
                        outputChannelBuffer[frame] = Float(int16Value) * gain
                    } else {
                        outputChannelBuffer[frame] = 0.0
                    }
                }

                // Zero out remaining frames
                for frame in actualFrameCount ..< audioBuffer.frames {
                    outputChannelBuffer[frame] = 0.0
                }

                // Play back the resampled audio using the resampled sample rate
                if let pcmBuffer = createAVAudioPCMBuffer(from: audioBuffer, sampleRate: targetOutputRate) {
                    let finalBuffer = convertToOutputFormat(pcmBuffer)
                    playerNode.scheduleBuffer(finalBuffer, completionHandler: nil)

                    if !playerNode.isPlaying {
                        playerNode.play()
                    }
                }

            } catch {
                print("[ResamplerAudioProcessor] Error during resampling: \(error)")
            }
        }
    }

    func audioProcessingRelease() {
        stop()
    }

    // MARK: - Private Helpers

    private func initializeResamplerIfNeeded(inputRate: Double, numChannels: UInt32) throws {
        // Check if resampler needs to be reinitialized
        if let existingSettings = resamplerSettings,
           existingSettings.inputRate == inputRate,
           existingSettings.numChannels == numChannels
        {
            return // Already initialized with correct settings
        }

        // Create new resampler using the uniffi API
        let settings = LiveKitFFI.ResamplerSettings(
            inputRate: inputRate,
            outputRate: targetOutputRate,
            numChannels: numChannels,
            quality: .medium
        )

        resampler = try LiveKitFFI.Resampler(settings: settings)
        resamplerSettings = settings

        if inputRate == targetOutputRate {
            print("[ResamplerAudioProcessor] ⚠️ WARNING: Resampling \(inputRate)Hz -> \(targetOutputRate)Hz (same rate, no actual resampling needed)")
        } else {
            print("[ResamplerAudioProcessor] ✅ Initialized resampler: \(inputRate)Hz -> \(targetOutputRate)Hz, \(numChannels) channels")
        }
    }

    private func createAVAudioPCMBuffer(from buffer: LKAudioBuffer, sampleRate: Double) -> AVAudioPCMBuffer? {
        guard let audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                              sampleRate: sampleRate,
                                              channels: AVAudioChannelCount(buffer.channels),
                                              interleaved: false),
            let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat,
                                             frameCapacity: AVAudioFrameCount(buffer.frames))
        else { return nil }

        pcmBuffer.frameLength = AVAudioFrameCount(buffer.frames)

        guard let targetBufferPointer = pcmBuffer.floatChannelData else { return nil }

        // LKAudioBuffer contains Int16 values stored as Float, need to normalize to -1.0 to 1.0 for playback
        let normalizeScale = 1.0 / Float(Int16.max)

        for channel in 0 ..< buffer.channels {
            let sourceBuffer = buffer.rawBuffer(forChannel: channel)
            let targetBuffer = targetBufferPointer[channel]

            for frame in 0 ..< buffer.frames {
                // Normalize Int16-range values to -1.0 to 1.0 for Float32 playback
                targetBuffer[frame] = sourceBuffer[frame] * normalizeScale
            }
        }

        return pcmBuffer
    }

    private func convertToOutputFormat(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard let outputFormat else {
            return buffer
        }

        // If formats match, return as-is
        if buffer.format == outputFormat {
            return buffer
        }

        // Use cached converter or create new one
        if outputConverter == nil || outputConverter?.inputFormat != buffer.format {
            outputConverter = AVAudioConverter(from: buffer.format, to: outputFormat)
        }

        guard let converter = outputConverter else {
            print("[ResamplerAudioProcessor] Failed to create converter to output format")
            return buffer
        }

        // Compute output frame capacity
        let outputFrameCount = AVAudioFrameCount(
            Double(buffer.frameLength) * (outputFormat.sampleRate / buffer.format.sampleRate)
        )

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: outputFrameCount
        ) else {
            print("[ResamplerAudioProcessor] Failed to create output buffer")
            return buffer
        }

        var error: NSError?
        #if swift(>=6.0)
        nonisolated(unsafe) var bufferFilled = false
        #else
        var bufferFilled = false
        #endif

        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if bufferFilled {
                outStatus.pointee = .noDataNow
                return nil
            }
            outStatus.pointee = .haveData
            bufferFilled = true
            return buffer
        }

        if let error {
            print("[ResamplerAudioProcessor] Conversion error: \(error)")
            return buffer
        }

        // Adjust frameLength to match what was actually converted
        outputBuffer.frameLength = min(outputBuffer.frameLength, outputBuffer.frameCapacity)
        return outputBuffer
    }
}
