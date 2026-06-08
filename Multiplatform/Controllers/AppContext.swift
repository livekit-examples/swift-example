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
    @Published var isSampleAudioPrepared: Bool = false
    @Published var playbackMode: SoundPlaybackOptions.Mode = .concurrent
    @Published var playbackLoop: Bool = false
    @Published var playbackDestination: SoundPlaybackOptions.Destination = .localAndRemote
    private var sampleAudio: SoundHandle?
    private var mutedSpeechToastHideTask: Task<Void, Never>?

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

    @Published var isVoiceProcessingAGCEnabled: Bool = false {
        didSet { AudioManager.shared.isVoiceProcessingAGCEnabled = isVoiceProcessingAGCEnabled }
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

    @Published var runtimeEchoCancellation: Bool = true
    @Published var runtimeNoiseSuppression: Bool = true
    @Published var runtimeAutoGainControl: Bool = true
    @Published var runtimeHighPassFilter: Bool = false
    @Published var runtimeEchoCancellationMode: AudioProcessingMode = .automatic
    @Published var runtimeNoiseSuppressionMode: AudioProcessingMode = .automatic
    @Published var runtimeAutoGainControlMode: AudioProcessingMode = .automatic
    @Published var runtimeHighPassFilterMode: AudioProcessingMode = .automatic
    @Published var runtimeAudioProcessingStatus: String = ""
    @Published var builtInAudioProcessingSummary: String = ""
    @Published private(set) var appliedRuntimeAudioProcessingOptions = AudioProcessingOptions()
    @Published var runtimeAudioProcessingEffectiveStates: [AudioProcessingEffectiveState] = []

    var runtimeAudioProcessingOptions: AudioProcessingOptions {
        AudioProcessingOptions(
            echoCancellation: runtimeEchoCancellation,
            autoGainControl: runtimeAutoGainControl,
            noiseSuppression: runtimeNoiseSuppression,
            highPassFilter: runtimeHighPassFilter,
            echoCancellationMode: runtimeEchoCancellationMode,
            autoGainControlMode: runtimeAutoGainControlMode,
            noiseSuppressionMode: runtimeNoiseSuppressionMode,
            highPassFilterMode: runtimeHighPassFilterMode
        )
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

    @Published var isRecordingAlwaysPreparedMode: Bool = false {
        didSet {
            Task {
                do {
                    try await AudioManager.shared.setRecordingAlwaysPreparedMode(
                        isRecordingAlwaysPreparedMode,
                        audioProcessingOptions: runtimeAudioProcessingOptions
                    )
                } catch {
                    print("Failed to set recording always prepared mode: \(error)")
                }
            }
        }
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

    @Published var showMutedSpeechToast: Bool = false

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

        AudioManager.shared.onMutedSpeechActivity = { [weak self] _, event in
            guard let self else { return }
            guard case .started = event else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                withAnimation {
                    showMutedSpeechToast = true
                }
                mutedSpeechToastHideTask?.cancel()
                mutedSpeechToastHideTask = Task { @MainActor [weak self] in
                    guard let self else { return }
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    withAnimation {
                        showMutedSpeechToast = false
                    }
                }
            }
        }

        outputDevices = AudioManager.shared.outputDevices
        inputDevices = AudioManager.shared.inputDevices
        outputDevice = AudioManager.shared.outputDevice
        inputDevice = AudioManager.shared.inputDevice
        isVoiceProcessingEnabled = AudioManager.shared.isVoiceProcessingEnabled
        isVoiceProcessingAGCEnabled = AudioManager.shared.isVoiceProcessingAGCEnabled
        isRecordingAlwaysPreparedMode = AudioManager.shared.isRecordingAlwaysPreparedMode
        refreshBuiltInAudioProcessingState()
        updateAudioDeviceSelections()
    }
}

struct AudioProcessingEffectiveState: Identifiable, Sendable {
    let id: String
    let title: String
    let result: AudioProcessingEffectiveResult
    let detail: String
}

enum AudioProcessingEffectiveResult: String, Sendable {
    case platform = "Platform"
    case software = "Software"
    case disabled = "Disabled"
    case unavailable = "Unavailable"
    case unknown = "Unknown"
}

extension AppContext {
    func markRuntimeAudioProcessingOptionsApplied(_ options: AudioProcessingOptions? = nil) {
        appliedRuntimeAudioProcessingOptions = options ?? runtimeAudioProcessingOptions
    }

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

    func refreshBuiltInAudioProcessingState() {
        let state = AudioManager.shared.builtInAudioProcessingState
        let engineAvailability = AudioManager.shared.engineAvailability
        let topology = switch state.topology {
        case .independent: "independent"
        case .echoCancellationAndNoiseSuppressionCoupled: "AEC/NS coupled"
        }
        let audioProcessingOptions = appliedRuntimeAudioProcessingOptions
        let effectiveStates = audioProcessingEffectiveStates(for: audioProcessingOptions, builtInState: state)
        runtimeAudioProcessingEffectiveStates = effectiveStates
        builtInAudioProcessingSummary = [
            "LiveKit audio processing diagnostics",
            "generatedAt: \(ISO8601DateFormatter().string(from: Date()))",
            "platform: \(platformName)",
            "",
            "App voice processing controls",
            "  voiceProcessingEnabled: \(boolSummary(AudioManager.shared.isVoiceProcessingEnabled))",
            "  voiceProcessingBypassed: \(boolSummary(AudioManager.shared.isVoiceProcessingBypassed))",
            "  voiceProcessingAGCEnabled: \(boolSummary(AudioManager.shared.isVoiceProcessingAGCEnabled))",
            "",
            "Runtime AudioProcessingOptions applied",
            "  echoCancellation: \(componentRequest(audioProcessingOptions.echoCancellation, audioProcessingOptions.echoCancellationMode))",
            "  noiseSuppression: \(componentRequest(audioProcessingOptions.noiseSuppression, audioProcessingOptions.noiseSuppressionMode))",
            "  autoGainControl: \(componentRequest(audioProcessingOptions.autoGainControl, audioProcessingOptions.autoGainControlMode))",
            "  highPassFilter: \(componentRequest(audioProcessingOptions.highPassFilter, audioProcessingOptions.highPassFilterMode))",
            "",
            "Current effective processing",
            "  echoCancellation: \(effectiveStateSummary(effectiveStates[0]))",
            "  noiseSuppression: \(effectiveStateSummary(effectiveStates[1]))",
            "  autoGainControl: \(effectiveStateSummary(effectiveStates[2]))",
            "  highPassFilter: \(effectiveStateSummary(effectiveStates[3]))",
            "",
            "Audio engine",
            "  engineRunning: \(boolSummary(AudioManager.shared.isEngineRunning))",
            "  inputAvailable requested: \(boolSummary(isAudioEngineInputAvailable))",
            "  inputAvailable effective: \(boolSummary(engineAvailability.isInputAvailable))",
            "  outputAvailable requested: \(boolSummary(isAudioEngineOutputAvailable))",
            "  outputAvailable effective: \(boolSummary(engineAvailability.isOutputAvailable))",
            "",
            "Built-in audio processing topology",
            "  topology: \(topology)",
            "  echoCancellation: \(componentSummary(state.echoCancellation))",
            "  noiseSuppression: \(componentSummary(state.noiseSuppression))",
            "  autoGainControl: \(componentSummary(state.autoGainControl))",
            "",
            "Apple Voice Processing I/O state",
            "  voiceProcessingEnabled requested: \(optionalSummary(state.isVoiceProcessingEnabledRequested))",
            "  voiceProcessingEnabled active: \(optionalSummary(state.isVoiceProcessingEnabledActive))",
            "  voiceProcessingBypassed requested: \(optionalSummary(state.isVoiceProcessingBypassedRequested))",
            "  voiceProcessingBypassed active: \(optionalSummary(state.isVoiceProcessingBypassedActive))",
            "  voiceProcessingAGC requested: \(optionalSummary(state.isVoiceProcessingAGCEnabledRequested))",
            "  voiceProcessingAGC active: \(optionalSummary(state.isVoiceProcessingAGCEnabledActive))",
            "",
            "Notes",
            "  requested values come from the ADM state.",
            "  active values come from the platform input node when available.",
            "  software effective state is inferred from the applied request and platform state.",
            "  active values can be unknown before the input path is configured.",
            "  subscribe-only playback does not configure the input path.",
        ].joined(separator: "\n")
    }

    func audioProcessingEffectiveStates(
        for options: AudioProcessingOptions,
        builtInState state: BuiltInAudioProcessingState
    ) -> [AudioProcessingEffectiveState] {
        [
            audioProcessingEffectiveState(
                id: "aec",
                title: "AEC",
                enabled: options.echoCancellation,
                mode: options.echoCancellationMode,
                platform: state.echoCancellation
            ),
            audioProcessingEffectiveState(
                id: "ns",
                title: "NS",
                enabled: options.noiseSuppression,
                mode: options.noiseSuppressionMode,
                platform: state.noiseSuppression
            ),
            audioProcessingEffectiveState(
                id: "agc",
                title: "AGC",
                enabled: options.autoGainControl,
                mode: options.autoGainControlMode,
                platform: state.autoGainControl
            ),
            audioProcessingEffectiveState(
                id: "hpf",
                title: "HPF",
                enabled: options.highPassFilter,
                mode: options.highPassFilterMode,
                platform: nil
            ),
        ]
    }

    func audioProcessingEffectiveState(
        id: String,
        title: String,
        enabled: Bool,
        mode: AudioProcessingMode,
        platform: BuiltInAudioProcessingComponentState?
    ) -> AudioProcessingEffectiveState {
        if let platform, platform.isActive == true {
            return AudioProcessingEffectiveState(
                id: id,
                title: title,
                result: .platform,
                detail: enabled ? "platform effect is active" : "platform effect is active despite disabled request"
            )
        }

        guard enabled else {
            return AudioProcessingEffectiveState(
                id: id,
                title: title,
                result: .disabled,
                detail: "disabled by applied request"
            )
        }

        guard let platform else {
            return AudioProcessingEffectiveState(
                id: id,
                title: title,
                result: mode == .platform ? .unavailable : .software,
                detail: mode == .platform ? "no platform backend exists for this component" : "software processing requested"
            )
        }

        switch mode {
        case .software:
            return AudioProcessingEffectiveState(
                id: id,
                title: title,
                result: .software,
                detail: "software processing requested"
            )
        case .automatic:
            if !platform.isAvailable {
                return AudioProcessingEffectiveState(
                    id: id,
                    title: title,
                    result: .software,
                    detail: "platform unavailable, using software fallback"
                )
            }
            if platform.isActive == false {
                return AudioProcessingEffectiveState(
                    id: id,
                    title: title,
                    result: .software,
                    detail: "platform inactive, using software fallback"
                )
            }
            return AudioProcessingEffectiveState(
                id: id,
                title: title,
                result: .unknown,
                detail: "waiting for platform readback"
            )
        case .platform:
            let detail = platform.isAvailable ? "platform requested but not active" : "platform unavailable"
            return AudioProcessingEffectiveState(
                id: id,
                title: title,
                result: .unavailable,
                detail: detail
            )
        }
    }

    func componentSummary(_ state: BuiltInAudioProcessingComponentState) -> String {
        "available: \(boolSummary(state.isAvailable)), " +
            "requested: \(optionalSummary(state.isRequested)), " +
            "active: \(optionalSummary(state.isActive))"
    }

    func effectiveStateSummary(_ state: AudioProcessingEffectiveState) -> String {
        "result: \(state.result.rawValue), \(state.detail)"
    }

    func optionalSummary(_ value: Bool?) -> String {
        value.map { $0 ? "on" : "off" } ?? "unknown"
    }

    func boolSummary(_ value: Bool) -> String {
        value ? "on" : "off"
    }

    func componentRequest(_ enabled: Bool, _ mode: AudioProcessingMode) -> String {
        "enabled: \(boolSummary(enabled)), mode: \(mode.description)"
    }

    var platformName: String {
        #if os(iOS)
        "iOS"
        #elseif os(macOS)
        "macOS"
        #elseif os(visionOS)
        "visionOS"
        #elseif os(tvOS)
        "tvOS"
        #else
        "unknown"
        #endif
    }
}

// MARK: - AudioClips

@MainActor
extension AppContext {
    func prepareSampleAudio() async {
        guard let url = Bundle.main.url(forResource: "livekit_clip01", withExtension: "m4a") else {
            print("Audio file not found")
            return
        }

        do {
            sampleAudio = try await SoundPlayer.shared.prepare(fileURL: url, named: "sample01")
            isSampleAudioPrepared = true
        } catch {
            print("Failed to prepare sample audio clip: \(error)")
        }
    }

    func playSampleAudio() async {
        guard let sampleAudio else {
            print("Sample audio clip is not prepared")
            return
        }

        let options = SoundPlaybackOptions(mode: playbackMode,
                                           loop: playbackLoop,
                                           destination: playbackDestination)

        do {
            try await sampleAudio.play(options: options)
            isSampleAudioPlaying = true
        } catch {
            print("Failed to play sample audio clip: \(error)")
        }
    }

    func stopSampleAudio() async {
        await sampleAudio?.stop()
        isSampleAudioPlaying = false
    }

    func releaseSampleAudio() async {
        await sampleAudio?.release()
        sampleAudio = nil
        isSampleAudioPrepared = false
        isSampleAudioPlaying = false
    }
}
