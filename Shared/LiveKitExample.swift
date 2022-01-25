import SwiftUI
import Logging
import LiveKit

struct AppContextView: View {

    @StateObject var appCtrl = AppContextCtrl()

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if appCtrl.connectionState.isConnected ||
                appCtrl.connectionState.isReconnecting {
                RoomView()
                    .environmentObject(DebugCtrl())
            } else {
                ConnectView()
            }

        }.foregroundColor(Color.white)
        .environmentObject(appCtrl)
        .environmentObject(appCtrl.room)
        .navigationTitle("LiveKit")
    }
}

@main
struct LiveKitExample: App {

    init() {
        LoggingSystem.bootstrap({ LiveKitLogHandler(label: $0) })
    }

    var body: some Scene {
        WindowGroup {
            AppContextView()
        }
    }
}
