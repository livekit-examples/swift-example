import SwiftUI
import LiveKit
import WebRTC
import Combine

extension ObservableObject where Self.ObjectWillChangePublisher == ObservableObjectPublisher {
    func notify() {
        DispatchQueue.main.async { self.objectWillChange.send() }
    }
}

// This class contains the logic to control behavior of the whole app.
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

    @Published var connectionHistory: Set<ConnectionHistory> = [] {
        didSet { store.value.connectionHistory = connectionHistory }
    }

    @Published var outputDevice: RTCIODevice = RTCIODevice.defaultDevice(with: .output) {
        didSet {
            print("didSet outputDevice: \(String(describing: outputDevice))")
            Room.audioDeviceModule.outputDevice = outputDevice
        }
    }

    @Published var inputDevice: RTCIODevice = RTCIODevice.defaultDevice(with: .input) {
        didSet {
            print("didSet inputDevice: \(String(describing: inputDevice))")
            Room.audioDeviceModule.inputDevice = inputDevice
        }
    }

    @Published var preferSpeakerOutput: Bool = true {
        didSet { AudioManager.shared.preferSpeakerOutput = preferSpeakerOutput }
    }

    public init(store: ValueStore<Preferences>) {
        self.store = store

        self.videoViewVisible = store.value.videoViewVisible
        self.showInformationOverlay = store.value.showInformationOverlay
        self.preferSampleBufferRendering = store.value.preferSampleBufferRendering
        self.videoViewMode = store.value.videoViewMode
        self.videoViewMirrored = store.value.videoViewMirrored
        self.connectionHistory = store.value.connectionHistory

        Room.audioDeviceModule.setDevicesUpdatedHandler {
            print("devices did update")
            // force UI update for outputDevice / inputDevice
            DispatchQueue.main.async {
                self.outputDevice = Room.audioDeviceModule.outputDevice
                self.inputDevice = Room.audioDeviceModule.inputDevice
            }
        }
    }
}
