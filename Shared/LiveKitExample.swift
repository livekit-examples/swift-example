import SwiftUI
import Logging
import LiveKit

struct AppContextView: View {

    @StateObject var appCtrl = AppContextCtrl()

    var shouldShowRoomView: Bool {
        appCtrl.connectionState.isConnected || appCtrl.connectionState.isReconnecting
    }

    func computeTitle() -> String {
        if shouldShowRoomView {
            let elements = [appCtrl.room.room.name,
                            appCtrl.room.room.localParticipant?.name,
                            appCtrl.room.room.localParticipant?.identity]
            return elements.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        }

        return "LiveKit"
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if shouldShowRoomView {
                RoomView().environmentObject(DebugCtrl())
            } else {
                ConnectView()
            }

        }.foregroundColor(Color.white)
        .environmentObject(appCtrl)
        .environmentObject(appCtrl.room)
        .navigationTitle(computeTitle())
        .onDisappear {
            print("\(String(describing: type(of: self))) onDisappear")
            appCtrl.disconnect()
        }
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
        #if os(macOS)
        .windowStyle(.automatic)
        .windowToolbarStyle(.automatic)
        #endif
    }
}
