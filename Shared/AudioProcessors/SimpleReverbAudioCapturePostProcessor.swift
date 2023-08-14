import Foundation
import LiveKit
import WebRTC

class SimpleReverbAudioCapturePostProcessor: NSObject, RTCAudioCustomProcessingDelegate {

    private var delayBuffer: [Float]
    private let delayBufferSize: Int = 4410  // 0.1 second at 44.1kHz
    private var delayBufferIndex: Int = 0
    private let feedback: Float = 0.6

    override init() {
        delayBuffer = Array(repeating: 0.0, count: delayBufferSize)
        super.init()
    }

    func initialize(sampleRateHz: Int, numChannels: Int) {
        print("\(String(describing: self)) initialize(sampleRateHz: \(sampleRateHz), numChannels: \(numChannels))")
    }

    func process(audioBuffer: RTCAudioBuffer) {
        print("\(String(describing: self)) process(audioBuffer: \(audioBuffer))")

        for channelIndex in 0..<audioBuffer.channels {
            let channelBuffer = audioBuffer.rawBuffer(forChannel: channelIndex)

            for frameIndex in 0..<audioBuffer.frames {
                let inputSample = channelBuffer[frameIndex]
                let delayedSample = delayBuffer[delayBufferIndex]

                // Mix the current sample with the delayed sample
                let outputSample = inputSample + delayedSample * feedback

                // Store the output sample into the delay buffer
                delayBuffer[delayBufferIndex] = outputSample

                // Write the output sample back to the channel buffer
                channelBuffer[frameIndex] = outputSample

                // Increment and wrap the delay buffer index
                delayBufferIndex = (delayBufferIndex + 1) % delayBufferSize
            }
        }
    }

    func destroy() {
        print("\(String(describing: self)) destroy()")
        delayBuffer.removeAll()
    }
}
