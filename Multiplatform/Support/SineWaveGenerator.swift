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

import AVFoundation
import LiveKit

/// A simple sine wave generator for testing audio buffer capture
@MainActor
final class SineWaveGenerator: ObservableObject {
    @Published var isGenerating: Bool = false
    @Published var frequency: Double = 440.0 // A4 note
    @Published var amplitude: Float = 0.5

    private var generationTask: Task<Void, Never>?
    private let sampleRate: Double = 48000.0
    private let bufferSize: AVAudioFrameCount = 2 * 480 // 20ms at 48kHz

    func startGenerating() {
        guard !isGenerating else { return }

        isGenerating = true
        generationTask = Task {
            await generateSineWave()
        }
    }

    func stopGenerating() {
        isGenerating = false
        generationTask?.cancel()
        generationTask = nil
    }

    private func generateSineWave() async {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        var phase = 0.0

        while isGenerating, !Task.isCancelled {
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize)!
            buffer.frameLength = bufferSize

            guard let channelData = buffer.floatChannelData?[0] else {
                continue
            }

            // Generate sine wave samples
            for frame in 0 ..< Int(bufferSize) {
                let sample = Float(sin(phase)) * amplitude
                channelData[frame] = sample
                phase += 2.0 * .pi * frequency / sampleRate

                // Keep phase in range to prevent overflow
                if phase > 2.0 * .pi {
                    phase -= 2.0 * .pi
                }
            }

            // Capture the audio buffer
            AudioManager.shared.mixer.capture(appAudio: buffer)

            // Wait for next buffer (10ms)
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }
}
