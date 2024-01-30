/*
 * Copyright 2023 LiveKit
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
        "fake_audio_processor"
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
