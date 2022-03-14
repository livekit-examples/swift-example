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

    @Published var preferMetal: Bool = true {
        didSet { store.value.preferMetal = preferMetal }
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

    @Published var outputDevice: RTCAudioDevice = RTCAudioDevice.defaultDevice(with: .output) {
        didSet {
            print("didSet outputDevice: \(String(describing: outputDevice))")

            let adm = Room.audioDeviceModule()
            if !adm.setOutputDevice(outputDevice) {
                print("failed to set value")
            }
        }
    }

    @Published var inputDevice: RTCAudioDevice = RTCAudioDevice.defaultDevice(with: .input) {
        didSet {
            print("didSet inputDevice: \(String(describing: inputDevice))")

            let adm = Room.audioDeviceModule()
            if !adm.setInputDevice(inputDevice) {
                print("failed to set value")
            }
        }
    }

    public init(store: ValueStore<Preferences>) {
        self.store = store

        store.onLoaded.then { preferences in
            self.videoViewVisible = preferences.videoViewVisible
            self.showInformationOverlay = preferences.showInformationOverlay
            self.preferMetal = preferences.preferMetal
            self.videoViewMode = preferences.videoViewMode
            self.videoViewMirrored = preferences.videoViewMirrored
            self.connectionHistory = preferences.connectionHistory
        }
    }
}
