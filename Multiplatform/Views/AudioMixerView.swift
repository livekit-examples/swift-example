/*
 * Copyright 2026 LiveKit
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

import LiveKit
import SwiftUI

#if !os(tvOS)
struct AudioMixerView: View {
    @EnvironmentObject var appCtx: AppContext

    var body: some View {
        Form {
            Section(header: Text("Audio Mixer")) {
//        Text("Audio controls")
//            .fontWeight(.bold)
                HStack {
                    Text("Mic")
                    Slider(value: $appCtx.micVolume, in: 0.0 ... 1.0)
                }
                HStack {
                    Text("App")
                    Slider(value: $appCtx.appVolume, in: 0.0 ... 1.0)
                }
            }

            Section(header: Text("Audio Ducking")) {
                Toggle("Advanced mode", isOn: $appCtx.isAdvancedDuckingEnabled)

                Picker("Level", selection: $appCtx.audioDuckingLevel) {
                    ForEach([AudioDuckingLevel.default,
                             AudioDuckingLevel.min,
                             AudioDuckingLevel.mid,
                             AudioDuckingLevel.max], id: \.self)
                    { mode in
                        Text("\(String(describing: mode))").tag(mode)
                    }
                }
            }

            Section(header: Text("Sample audio clip")) {
                if appCtx.isSampleAudioPlaying {
                    Button {
                        appCtx.stopSampleAudio()
                    } label: {
                        Text("Stop")
                    }
                } else {
                    Button {
                        appCtx.playSampleAudio()
                    } label: {
                        Text("Play")
                    }
                }
            }
        }.formStyle(.grouped)
    }
}
#endif
