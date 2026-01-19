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
struct AudioControlsPanel: View {
    @EnvironmentObject var appCtx: AppContext

    private var inputDeviceSelection: Binding<AudioDevice.ID> {
        Binding(
            get: { appCtx.inputDevice.id },
            set: { newId in
                if let match = appCtx.inputDevices.first(where: { $0.id == newId }) {
                    appCtx.inputDevice = match
                }
            }
        )
    }

    private var outputDeviceSelection: Binding<AudioDevice.ID> {
        Binding(
            get: { appCtx.outputDevice.id },
            set: { newId in
                if let match = appCtx.outputDevices.first(where: { $0.id == newId }) {
                    appCtx.outputDevice = match
                }
            }
        )
    }

    var body: some View {
        Form {
            Section(header: Text("Audio Mixer")) {
                HStack {
                    Text("Mic")
                    Slider(value: $appCtx.micVolume, in: 0.0 ... 1.0)
                }
                HStack {
                    Text("App")
                    Slider(value: $appCtx.appVolume, in: 0.0 ... 1.0)
                }
            }

            Section(header: Text("Audio Devices")) {
                if !appCtx.inputDevices.isEmpty {
                    Picker("Input", selection: inputDeviceSelection) {
                        ForEach(appCtx.inputDevices) { device in
                            Text(device.isDefault ? "Default (\(device.name))" : device.name)
                                .tag(device.id)
                        }
                    }
                }
                if !appCtx.outputDevices.isEmpty {
                    Picker("Output", selection: outputDeviceSelection) {
                        ForEach(appCtx.outputDevices) { device in
                            Text(device.isDefault ? "Default (\(device.name))" : device.name)
                                .tag(device.id)
                        }
                    }
                }
                #if os(iOS) || os(visionOS) || os(tvOS)
                Toggle("Prefer speaker", isOn: $appCtx.preferSpeakerOutput)
                #endif
            }

            Section(header: Text("Voice Processing")) {
                Toggle("Bypass voice processing", isOn: $appCtx.isVoiceProcessingBypassed)
                Picker("Mic mute mode", selection: $appCtx.micMuteMode) {
                    ForEach([MicrophoneMuteMode.voiceProcessing,
                             MicrophoneMuteMode.restart,
                             MicrophoneMuteMode.inputMixer], id: \.self)
                    { mode in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(String(describing: mode))")
                            Text(micMuteModeDescription(for: mode))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(mode)
                    }
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

private extension AudioControlsPanel {
    func micMuteModeDescription(for mode: MicrophoneMuteMode) -> String {
        switch mode {
        case .voiceProcessing:
            return "Fast and turns mic indicator off, iOS plays a short beep."
        case .restart:
            return "Slow and reconfigures the audio session, no iOS beep."
        case .inputMixer:
            return "Fast but mic indicator stays on, no iOS beep."
        @unknown default:
            return "Uses default mute handling."
        }
    }
}
#endif
