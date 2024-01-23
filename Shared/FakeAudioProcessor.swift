//
//  FakeAudioProcessor.swift
//  LiveKitExample
//
//  Created by 段维伟 on 2024/1/23.
//

import Foundation
import LiveKit

class FakeAudioProcessor: AudioProcessor {

    public init() {

    }
    func isEnabled(url: String, token: String) -> Bool {
        print("check \(getName()) isEnabled: url: \(url) token: \(token)")
        return true
    }

    func getName() -> String {
        "facke_audio_processor"
    }

    func audioProcessingInitialize(sampleRate sampleRateHz: Int, channels: Int) {
        print("\(getName()) audioProcessingInitialize: sampleRate: \(sampleRateHz) channels: \(channels)")
    }

    func audioProcessingProcess(audioBuffer: LKAudioBuffer) {
        print("\(getName()) audioProcessingProcess: \(String(describing: audioBuffer)) ")
    }

    func audioProcessingRelease() {
        print("\(getName()) audioProcessingRelease:")
    }
}
