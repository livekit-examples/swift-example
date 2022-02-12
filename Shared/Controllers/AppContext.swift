import SwiftUI
import LiveKit
import WebRTC

// This class contains the logic to control behavior of the whole app.
final class AppContext: ObservableObject {

    private let store: SecureStore<SecureStoreKeys>

    @Published var videoViewVisible: Bool {
        didSet { store.set(.videoViewVisible, value: videoViewVisible) }
    }

    @Published var showInformationOverlay: Bool {
        didSet { store.set(.showInformationOverlay, value: showInformationOverlay) }
    }

    @Published var preferMetal: Bool {
        didSet { store.set(.preferMetal, value: preferMetal) }
    }

    @Published var videoViewMode: VideoView.Mode {
        didSet { store.set(.videoViewMode, value: videoViewMode) }
    }

    @Published var videoViewMirrored: Bool {
        didSet { store.set(.videoViewMirrored, value: videoViewMirrored) }
    }

    @Published var connectionHistory: Set<ConnectionHistory> {
        didSet { store.set(.connectionHistory, value: connectionHistory) }
    }

    public init(store: SecureStore<SecureStoreKeys>) {
        self.store = store
        self.videoViewVisible = store.get(.videoViewVisible) ?? true
        self.showInformationOverlay = store.get(.showInformationOverlay) ?? false
        self.preferMetal = store.get(.preferMetal) ?? true
        self.videoViewMode = store.get(.videoViewMode) ?? .fit
        self.videoViewMirrored = store.get(.videoViewMirrored) ?? false
        self.connectionHistory = store.get(.connectionHistory) ?? Set<ConnectionHistory>()
    }
}
