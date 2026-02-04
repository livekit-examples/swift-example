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

import AVFAudio
import Combine
import LiveKit
import SwiftUI

// This class contains the logic to control behavior of the whole app.
@MainActor
final class AppContext: NSObject, ObservableObject {
    private let store: ValueStore<Preferences>

    @Published var isSampleAudioPlaying: Bool = false

    @Published var videoViewVisible: Bool = true {
        didSet { store.value.videoViewVisible = videoViewVisible }
    }

    @Published var showInformationOverlay: Bool = false {
        didSet { store.value.showInformationOverlay = showInformationOverlay }
    }

    @Published var preferSampleBufferRendering: Bool = false {
        didSet { store.value.preferSampleBufferRendering = preferSampleBufferRendering }
    }

    @Published var videoViewMode: VideoView.LayoutMode = .fit {
        didSet { store.value.videoViewMode = videoViewMode }
    }

    @Published var videoViewMirrored: Bool = false {
        didSet { store.value.videoViewMirrored = videoViewMirrored }
    }

    @Published var videoViewPinchToZoomOptions: VideoView.PinchToZoomOptions = []

    @Published var connectionHistory: Set<ConnectionHistory> = [] {
        didSet { store.value.connectionHistory = connectionHistory }
    }

    @Published var outputDevices: [AudioDevice] = []
    @Published var outputDevice: AudioDevice = AudioManager.shared.defaultOutputDevice {
        didSet {
            guard oldValue != outputDevice else { return }
            print("didSet outputDevice: \(String(describing: outputDevice))")
            AudioManager.shared.outputDevice = outputDevice
        }
    }

    @Published var inputDevices: [AudioDevice] = []
    @Published var inputDevice: AudioDevice = AudioManager.shared.defaultInputDevice {
        didSet {
            guard oldValue != inputDevice else { return }
            print("didSet inputDevice: \(String(describing: inputDevice))")
            AudioManager.shared.inputDevice = inputDevice
        }
    }

    #if os(iOS) || os(visionOS) || os(tvOS)
    @Published var preferSpeakerOutput: Bool = true {
        didSet { AudioManager.shared.isSpeakerOutputPreferred = preferSpeakerOutput }
    }
    #endif

    @Published var isVoiceProcessingBypassed: Bool = false {
        didSet { AudioManager.shared.isVoiceProcessingBypassed = isVoiceProcessingBypassed }
    }

    @Published var isVoiceProcessingEnabled: Bool = true {
        didSet {
            guard oldValue != isVoiceProcessingEnabled else { return }
            do {
                try AudioManager.shared.setVoiceProcessingEnabled(isVoiceProcessingEnabled)
            } catch {
                print("Failed to set voice processing enabled: \(error)")
            }
        }
    }

    @Published var micMuteMode: MicrophoneMuteMode = .voiceProcessing {
        didSet {
            do {
                try AudioManager.shared.set(microphoneMuteMode: micMuteMode)
            } catch {
                print("Failed to set mic mute mode: \(error)")
            }
        }
    }

    @Published var micVolume: Float = 1.0 {
        didSet { AudioManager.shared.mixer.micVolume = micVolume }
    }

    @Published var appVolume: Float = 1.0 {
        didSet { AudioManager.shared.mixer.appVolume = appVolume }
    }

    @Published var soundPlayerVolume: Float = 1.0 {
        didSet { AudioManager.shared.mixer.soundPlayerVolume = soundPlayerVolume }
    }

    @Published var isAdvancedDuckingEnabled: Bool = false {
        didSet {
            if #available(iOS 17, macOS 14.0, visionOS 1.0, *) {
                AudioManager.shared.isAdvancedDuckingEnabled = isAdvancedDuckingEnabled
            }
        }
    }

    @Published var audioDuckingLevel: AudioDuckingLevel = .min {
        didSet {
            if #available(iOS 17, macOS 14.0, visionOS 1.0, *) {
                AudioManager.shared.duckingLevel = audioDuckingLevel
            }
        }
    }

    @Published var isAudioEngineInputAvailable: Bool = true {
        didSet {
            do {
                try AudioManager.shared.setEngineAvailability(.init(isInputAvailable: isAudioEngineInputAvailable,
                                                                    isOutputAvailable: isAudioEngineOutputAvailable))
            } catch {
                print("Failed to set audio engine availability: \(error)")
            }
        }
    }

    @Published var isAudioEngineOutputAvailable: Bool = true {
        didSet {
            do {
                try AudioManager.shared.setEngineAvailability(.init(isInputAvailable: isAudioEngineInputAvailable,
                                                                    isOutputAvailable: isAudioEngineOutputAvailable))
            } catch {
                print("Failed to set audio engine availability: \(error)")
            }
        }
    }

    init(store: ValueStore<Preferences>) {
        self.store = store

        videoViewVisible = store.value.videoViewVisible
        showInformationOverlay = store.value.showInformationOverlay
        preferSampleBufferRendering = store.value.preferSampleBufferRendering
        videoViewMode = store.value.videoViewMode
        videoViewMirrored = store.value.videoViewMirrored
        connectionHistory = store.value.connectionHistory

        super.init()

        AudioManager.shared.onDeviceUpdate = { [weak self] _ in
            guard let self else { return }
            // force UI update for outputDevice / inputDevice
            Task { @MainActor [weak self] in
                guard let self else { return }
                outputDevices = AudioManager.shared.outputDevices
                inputDevices = AudioManager.shared.inputDevices
                outputDevice = AudioManager.shared.outputDevice
                inputDevice = AudioManager.shared.inputDevice
                updateAudioDeviceSelections()
            }
        }

        outputDevices = AudioManager.shared.outputDevices
        inputDevices = AudioManager.shared.inputDevices
        outputDevice = AudioManager.shared.outputDevice
        inputDevice = AudioManager.shared.inputDevice
        isVoiceProcessingEnabled = AudioManager.shared.isVoiceProcessingEnabled
        updateAudioDeviceSelections()
    }
}

private extension AppContext {
    func updateAudioDeviceSelections() {
        if !inputDevices.contains(where: { $0.id == inputDevice.id }) {
            if let defaultInput = inputDevices.first(where: { $0.isDefault }) {
                inputDevice = defaultInput
            } else if let firstInput = inputDevices.first {
                inputDevice = firstInput
            }
        }

        if !outputDevices.contains(where: { $0.id == outputDevice.id }) {
            if let defaultOutput = outputDevices.first(where: { $0.isDefault }) {
                outputDevice = defaultOutput
            } else if let firstOutput = outputDevices.first {
                outputDevice = firstOutput
            }
        }
    }
}

// MARK: - AudioClips

extension AppContext {
    func prepareSampleAudio() {
        guard let url = Bundle.main.url(forResource: "livekit_clip01", withExtension: "m4a") else {
            print("Audio file not found")
            return
        }
        do {
            try SoundPlayer.shared.prepare(url: url, withId: "sample01")
        } catch {
            print("Failed to prepare sample audio clip")
        }
    }

    func playSampleAudio() {
        do {
            isSampleAudioPlaying = true
            try SoundPlayer.shared.play(id: "sample01")
        } catch {
            print("Failed to sample audio clip")
        }
    }

    func stopSampleAudio() {
        SoundPlayer.shared.stop(id: "sample01")
        isSampleAudioPlaying = false
    }

    func releaseSampleAudio() {
        SoundPlayer.shared.release(id: "sample01")
    }
}

extension AppContext: @MainActor AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
        isSampleAudioPlaying = false
    }
}
