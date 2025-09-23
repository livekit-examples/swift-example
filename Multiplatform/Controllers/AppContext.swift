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

import Combine
import LiveKit
import SwiftUI

// This class contains the logic to control behavior of the whole app.
@MainActor
final class AppContext: ObservableObject {
    private let store: ValueStore<Preferences>

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

    init(store: ValueStore<Preferences>) {
        self.store = store

        videoViewVisible = store.value.videoViewVisible
        showInformationOverlay = store.value.showInformationOverlay
        preferSampleBufferRendering = store.value.preferSampleBufferRendering
        videoViewMode = store.value.videoViewMode
        videoViewMirrored = store.value.videoViewMirrored
        connectionHistory = store.value.connectionHistory

        AudioManager.shared.onDeviceUpdate = { [weak self] _ in
            guard let self else { return }
            // force UI update for outputDevice / inputDevice
            Task { @MainActor [weak self] in
                guard let self else { return }
                outputDevices = AudioManager.shared.outputDevices
                inputDevices = AudioManager.shared.inputDevices
                outputDevice = AudioManager.shared.outputDevice
                inputDevice = AudioManager.shared.inputDevice
            }
        }

        outputDevices = AudioManager.shared.outputDevices
        inputDevices = AudioManager.shared.inputDevices
        outputDevice = AudioManager.shared.outputDevice
        inputDevice = AudioManager.shared.inputDevice
    }
}
