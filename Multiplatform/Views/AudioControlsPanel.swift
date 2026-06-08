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

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if !os(tvOS)
struct AudioControlsPanel: View {
    @EnvironmentObject var appCtx: AppContext
    @EnvironmentObject var room: Room

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
                HStack {
                    Text("Sound player")
                    Slider(value: $appCtx.soundPlayerVolume, in: 0.0 ... 1.0)
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
                Toggle("Voice processing enabled", isOn: $appCtx.isVoiceProcessingEnabled)
                Toggle("Bypass voice processing", isOn: $appCtx.isVoiceProcessingBypassed)
                Toggle("Auto gain control (AGC)", isOn: $appCtx.isVoiceProcessingAGCEnabled)
            }

            Section(header: Text("Runtime Audio Processing")) {
                Toggle("Echo cancellation", isOn: $appCtx.runtimeEchoCancellation)
                modePicker("Echo mode", selection: $appCtx.runtimeEchoCancellationMode)

                Toggle("Noise suppression", isOn: $appCtx.runtimeNoiseSuppression)
                modePicker("Noise mode", selection: $appCtx.runtimeNoiseSuppressionMode)

                Toggle("Auto gain control", isOn: $appCtx.runtimeAutoGainControl)
                modePicker("Gain mode", selection: $appCtx.runtimeAutoGainControlMode)

                Toggle("High-pass filter", isOn: $appCtx.runtimeHighPassFilter)
                modePicker("HPF mode", selection: $appCtx.runtimeHighPassFilterMode)

                HStack {
                    Button("Apply to local mic") {
                        applyRuntimeAudioProcessingOptions()
                    }
                    Button("Get diagnostics") {
                        appCtx.refreshBuiltInAudioProcessingState()
                    }
                    Button("Copy diagnostics") {
                        copyAudioProcessingDiagnostics()
                    }
                }
                .buttonStyle(.bordered)

                if !appCtx.runtimeAudioProcessingStatus.isEmpty {
                    Text(appCtx.runtimeAudioProcessingStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !appCtx.builtInAudioProcessingSummary.isEmpty {
                    ScrollView {
                        Text(appCtx.builtInAudioProcessingSummary)
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(minHeight: 180, maxHeight: 260)
                }
            }

            Section(header: Text("Recording")) {
                Toggle("Always prepared", isOn: $appCtx.isRecordingAlwaysPreparedMode)
                Text("Keeps mic pipeline warmed for low-latency publish.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Mic mute mode")) {
                Picker("Mic mute mode", selection: $appCtx.micMuteMode) {
                    ForEach([MicrophoneMuteMode.voiceProcessing,
                             MicrophoneMuteMode.restart,
                             MicrophoneMuteMode.inputMixer], id: \.self)
                    { mode in
                        Text("\(String(describing: mode))").tag(mode)
                    }
                }
                Text(micMuteModeDescription(for: appCtx.micMuteMode))
                    .font(.caption)
                    .foregroundColor(.secondary)
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

            Section(header: Text("Sound Player")) {
                Picker("Mode", selection: $appCtx.playbackMode) {
                    Text("Concurrent").tag(SoundPlaybackOptions.Mode.concurrent)
                    Text("Replace").tag(SoundPlaybackOptions.Mode.replace)
                }

                Picker("Destination", selection: $appCtx.playbackDestination) {
                    Text("Local").tag(SoundPlaybackOptions.Destination.local)
                    Text("Remote").tag(SoundPlaybackOptions.Destination.remote)
                    Text("Local + Remote").tag(SoundPlaybackOptions.Destination.localAndRemote)
                }

                Toggle("Loop", isOn: $appCtx.playbackLoop)

                HStack {
                    Button("Prepare") {
                        Task {
                            await appCtx.prepareSampleAudio()
                        }
                    }
                    .disabled(appCtx.isSampleAudioPrepared)

                    Button("Play") {
                        Task {
                            await appCtx.playSampleAudio()
                        }
                    }
                    .disabled(!appCtx.isSampleAudioPrepared)

                    Button("Stop") {
                        Task {
                            await appCtx.stopSampleAudio()
                        }
                    }
                    .disabled(!appCtx.isSampleAudioPlaying)

                    Button("Release") {
                        Task {
                            await appCtx.releaseSampleAudio()
                        }
                    }
                    .disabled(!appCtx.isSampleAudioPrepared)
                }
                .buttonStyle(.bordered)
            }

            Section(header: Text("Audio Engine Availability")) {
                Toggle("Input available", isOn: $appCtx.isAudioEngineInputAvailable)
                Toggle("Output available", isOn: $appCtx.isAudioEngineOutputAvailable)
            }
        }.formStyle(.grouped)
    }
}

private extension AudioControlsPanel {
    var localMicrophoneTrack: LocalAudioTrack? {
        room.localParticipant.audioTracks
            .first(where: { $0.source == .microphone })?
            .track as? LocalAudioTrack
    }

    func modePicker(_ title: String, selection: Binding<AudioProcessingMode>) -> some View {
        Picker(title, selection: selection) {
            ForEach(AudioProcessingMode.allCases, id: \.self) { mode in
                Text(mode.description).tag(mode)
            }
        }
    }

    func applyRuntimeAudioProcessingOptions() {
        guard let localMicrophoneTrack else {
            appCtx.runtimeAudioProcessingStatus = "Publish the microphone first."
            appCtx.refreshBuiltInAudioProcessingState()
            return
        }

        do {
            let result = try localMicrophoneTrack.setAudioProcessingOptions(appCtx.runtimeAudioProcessingOptions)
            appCtx.runtimeAudioProcessingStatus = if result.message.isEmpty {
                "Audio processing options: \(result.code)"
            } else {
                "Audio processing options: \(result.code): \(result.message)"
            }
        } catch {
            appCtx.runtimeAudioProcessingStatus = "Failed: \(error)"
        }
        appCtx.refreshBuiltInAudioProcessingState()
    }

    func copyAudioProcessingDiagnostics() {
        appCtx.refreshBuiltInAudioProcessingState()
        let diagnostics = appCtx.builtInAudioProcessingSummary
        #if canImport(UIKit)
        UIPasteboard.general.string = diagnostics
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnostics, forType: .string)
        #endif
        appCtx.runtimeAudioProcessingStatus = "Diagnostics copied."
    }

    func micMuteModeDescription(for mode: MicrophoneMuteMode) -> String {
        switch mode {
        case .voiceProcessing:
            return "Fast and turns mic indicator off, iOS plays a short beep."
        case .restart:
            return "Slow and reconfigures the audio session, no iOS beep."
        case .inputMixer:
            return "Fast but mic indicator stays on, no iOS beep."
        case .unknown:
            return "Uses default mute handling."
        @unknown default:
            return "Uses default mute handling."
        }
    }
}
#endif
