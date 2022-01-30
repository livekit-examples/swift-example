import SwiftUI
import LiveKit
import WebRTC

// This class contains the logic to control behavior of the whole app.
final class AppContext: ObservableObject {
    @AppStorage("connectionHistory") var connectionHistory = ConnectionHistory()
    @AppStorage("videoViewVisible") var videoViewVisible: Bool = true
    @AppStorage("showInformationOverlay") var showInformationOverlay: Bool = false
    @AppStorage("preferMetal") var preferMetal: Bool = true
    @AppStorage("videoViewMode") var videoViewMode: VideoView.Mode = .fill
}
