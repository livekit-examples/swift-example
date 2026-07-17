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

    @Published var isPlatformVoiceProcessingAllowed: Bool = true {
        didSet {
            guard oldValue != isPlatformVoiceProcessingAllowed else { return }
            do {
                try AudioManager.shared.setPlatformVoiceProcessingAllowed(isPlatformVoiceProcessingAllowed)
            } catch {
                print("Failed to set platform voice processing allowed: \(error)")
            }
        }
    }

    @Published var runtimeEchoCancellation: Bool = true
    @Published var runtimeNoiseSuppression: Bool = true
    @Published var runtimeAutoGainControl: Bool = true
    @Published var runtimeHighPassFilter: Bool = false
    @Published var runtimeEchoCancellationMode: EchoCancellationMode = .automatic
    @Published var runtimeNoiseSuppressionMode: NoiseSuppressionMode = .automatic
    @Published var runtimeAutoGainControlMode: AutoGainControlMode = .automatic
    @Published var runtimeHighPassFilterMode: HighpassFilterMode = .automatic
    @Published var runtimeAudioProcessingStatus: String = ""
    @Published var audioProcessingSummary: String = ""
    @Published var runtimeAudioProcessingEffectiveStates: [AudioProcessingEffectiveState] = []

    var runtimeAudioProcessingOptions: AudioProcessingOptions {
        AudioProcessingOptions(
            echoCancellation: runtimeEchoCancellation,
            autoGainControl: runtimeAutoGainControl,
            noiseSuppression: runtimeNoiseSuppression,
            highpassFilter: runtimeHighPassFilter,
            echoCancellationMode: runtimeEchoCancellationMode,
            autoGainControlMode: runtimeAutoGainControlMode,
            noiseSuppressionMode: runtimeNoiseSuppressionMode,
            highpassFilterMode: runtimeHighPassFilterMode
        )
    }

    var runtimeAudioCaptureOptions: AudioCaptureOptions {
        AudioCaptureOptions(
            echoCancellation: runtimeEchoCancellation,
            autoGainControl: runtimeAutoGainControl,
            noiseSuppression: runtimeNoiseSuppression,
            highpassFilter: runtimeHighPassFilter,
            echoCancellationMode: runtimeEchoCancellationMode,
            autoGainControlMode: runtimeAutoGainControlMode,
            noiseSuppressionMode: runtimeNoiseSuppressionMode,
            highpassFilterMode: runtimeHighPassFilterMode
        )
    }

    func setRuntimeProcessingControls(_ options: AudioProcessingOptions) {
        runtimeEchoCancellation = options.echoCancellation
        runtimeAutoGainControl = options.autoGainControl
        runtimeNoiseSuppression = options.noiseSuppression
        runtimeHighPassFilter = options.highpassFilter
        runtimeEchoCancellationMode = options.echoCancellationMode
        runtimeAutoGainControlMode = options.autoGainControlMode
        runtimeNoiseSuppressionMode = options.noiseSuppressionMode
        runtimeHighPassFilterMode = options.highpassFilterMode
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
        isPlatformVoiceProcessingAllowed = AudioManager.shared.isPlatformVoiceProcessingAllowed
        isVoiceProcessingAGCEnabled = AudioManager.shared.isVoiceProcessingAGCEnabled
        isRecordingAlwaysPreparedMode = AudioManager.shared.isRecordingAlwaysPreparedMode
        refreshAudioProcessingState()
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
    case softwareAndPlatform = "Software + Platform"
    case disabled = "Disabled"
    case unknown = "Unknown"
}

extension AppContext {
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

    func refreshAudioProcessingState() {
        let state = AudioManager.shared.audioProcessingState
        let platformState = AudioManager.shared.platformVoiceProcessingState
        let engineAvailability = AudioManager.shared.engineAvailability
        let topology = switch platformState.topology {
        case .independent: "independent"
        case .echoCancellationAndNoiseSuppressionCoupled: "AEC/NS coupled"
        }
        let audioProcessingOptions = runtimeAudioProcessingOptions
        runtimeAudioProcessingEffectiveStates = audioProcessingEffectiveStates(for: state)
        audioProcessingSummary = [
            "LiveKit audio processing diagnostics",
            "generatedAt: \(ISO8601DateFormatter().string(from: Date()))",
            "platform: \(platformName)",
            "",
            "App voice processing controls",
            "  platformVoiceProcessingAllowed: \(boolSummary(AudioManager.shared.isPlatformVoiceProcessingAllowed))",
            "  voiceProcessingBypassed: \(boolSummary(AudioManager.shared.isVoiceProcessingBypassed))",
            "  voiceProcessingAGCEnabled: \(boolSummary(AudioManager.shared.isVoiceProcessingAGCEnabled))",
            "",
            "Runtime AudioProcessingOptions controls",
            "  echoCancellation: \(componentRequest(audioProcessingOptions.echoCancellation, audioProcessingOptions.echoCancellationMode))",
            "  noiseSuppression: \(componentRequest(audioProcessingOptions.noiseSuppression, audioProcessingOptions.noiseSuppressionMode))",
            "  autoGainControl: \(componentRequest(audioProcessingOptions.autoGainControl, audioProcessingOptions.autoGainControlMode))",
            "  highPassFilter: \(componentRequest(audioProcessingOptions.highpassFilter, audioProcessingOptions.highpassFilterMode))",
            "",
            "Current effective processing",
            "  echoCancellation: \(effectiveStateSummary(state.echoCancellation))",
            "  noiseSuppression: \(effectiveStateSummary(state.noiseSuppression))",
            "  autoGainControl: \(effectiveStateSummary(state.autoGainControl))",
            "  highPassFilter: \(effectiveStateSummary(state.highpassFilter))",
            "",
            "Engine audio processing state",
            "  echoCancellation: \(runtimeComponentSummary(state.echoCancellation))",
            "  noiseSuppression: \(runtimeComponentSummary(state.noiseSuppression))",
            "  autoGainControl: \(runtimeComponentSummary(state.autoGainControl))",
            "  highPassFilter: \(runtimeComponentSummary(state.highpassFilter))",
            "",
            "Audio engine",
            "  engineRunning: \(boolSummary(AudioManager.shared.isEngineRunning))",
            "  inputAvailable requested: \(boolSummary(isAudioEngineInputAvailable))",
            "  inputAvailable effective: \(boolSummary(engineAvailability.isInputAvailable))",
            "  outputAvailable requested: \(boolSummary(isAudioEngineOutputAvailable))",
            "  outputAvailable effective: \(boolSummary(engineAvailability.isOutputAvailable))",
            "",
            "Platform audio processing topology",
            "  topology: \(topology)",
            "  echoCancellation: \(componentSummary(platformState.echoCancellation))",
            "  noiseSuppression: \(componentSummary(platformState.noiseSuppression))",
            "  autoGainControl: \(componentSummary(platformState.autoGainControl))",
            "",
            "Apple Voice Processing I/O state",
            "  voiceProcessingEnabled requested: \(boolSummary(platformState.voiceProcessingEnabled.isRequested))",
            "  voiceProcessingEnabled active: \(boolSummary(platformState.voiceProcessingEnabled.isActive))",
            "  voiceProcessingBypassed requested: \(boolSummary(platformState.voiceProcessingBypassed.isRequested))",
            "  voiceProcessingBypassed active: \(boolSummary(platformState.voiceProcessingBypassed.isActive))",
            "  voiceProcessingAGC requested: \(boolSummary(platformState.voiceProcessingAGCEnabled.isRequested))",
            "  voiceProcessingAGC active: \(boolSummary(platformState.voiceProcessingAGCEnabled.isActive))",
            "",
            "Notes",
            "  engine state comes from the factory-owned audio processing module.",
            "  requested values come from the ADM state.",
            "  active values come from the platform input node when available.",
            "  active values read off before the input path is configured.",
            "  subscribe-only playback does not configure the input path.",
        ].joined(separator: "\n")
    }

    func audioProcessingEffectiveStates(for state: AudioProcessingState) -> [AudioProcessingEffectiveState] {
        [
            audioProcessingEffectiveState(id: "aec", title: "AEC", component: state.echoCancellation),
            audioProcessingEffectiveState(id: "ns", title: "NS", component: state.noiseSuppression),
            audioProcessingEffectiveState(id: "agc", title: "AGC", component: state.autoGainControl),
            audioProcessingEffectiveState(id: "hpf", title: "HPF", component: state.highpassFilter),
        ]
    }

    func audioProcessingEffectiveState<Mode>(
        id: String,
        title: String,
        component: AudioProcessingComponentState<Mode>
    ) -> AudioProcessingEffectiveState {
        AudioProcessingEffectiveState(
            id: id,
            title: title,
            result: effectiveResult(component.effective),
            detail: runtimeComponentDetail(component)
        )
    }

    func componentSummary(_ state: PlatformVoiceProcessingComponentState) -> String {
        "available: \(boolSummary(state.isAvailable)), " +
            "requested: \(boolSummary(state.isRequested)), " +
            "active: \(boolSummary(state.isActive))"
    }

    func effectiveStateSummary<Mode>(_ component: AudioProcessingComponentState<Mode>) -> String {
        "result: \(component.effective.description), \(runtimeComponentDetail(component))"
    }

    func runtimeComponentSummary<Mode>(_ component: AudioProcessingComponentState<Mode>) -> String {
        let requested = component.requested
            .map { "\(boolSummary($0.isEnabled)) / \($0.mode)" } ?? "none"
        let platform = component.platform
            .map { "available: on, resolved: \(boolSummary($0.isResolved)), active: \(boolSummary($0.isActive))" }
            ?? "available: off"
        return "effective: \(component.effective.description), " +
            "requested: \(requested), " +
            "softwareResolved: \(boolSummary(component.software.isResolved)), " +
            "softwareActive: \(boolSummary(component.software.isActive)), " +
            "platform: \(platform)"
    }

    func runtimeComponentDetail<Mode>(_ component: AudioProcessingComponentState<Mode>) -> String {
        "software: \(boolSummary(component.software.isActive)), platform: \(boolSummary(component.platform?.isActive ?? false))"
    }

    func effectiveResult(_ implementation: AudioProcessingImplementation) -> AudioProcessingEffectiveResult {
        switch implementation {
        case .unknown: .unknown
        case .disabled: .disabled
        case .software: .software
        case .platform: .platform
        case .softwareAndPlatform: .softwareAndPlatform
        }
    }

    func boolSummary(_ value: Bool) -> String {
        value ? "on" : "off"
    }

    func componentRequest<Mode>(_ enabled: Bool, _ mode: Mode) -> String {
        "enabled: \(boolSummary(enabled)), mode: \(mode)"
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
