import SwiftUI
import Logging
import LiveKit

struct RoomContextView: View {

    @StateObject var roomCtx = RoomContext()

    var shouldShowRoomView: Bool {
        roomCtx.connectionState.isConnected || roomCtx.connectionState.isReconnecting
    }

    func computeTitle() -> String {
        if shouldShowRoomView {
            let elements = [roomCtx.room.room.name,
                            roomCtx.room.room.localParticipant?.name,
                            roomCtx.room.room.localParticipant?.identity]
            return elements.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        }

        return "LiveKit"
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if shouldShowRoomView {
                RoomView()
            } else {
                ConnectView()
            }

        }.foregroundColor(Color.white)
        .environmentObject(roomCtx)
        .environmentObject(roomCtx.room)
        .navigationTitle(computeTitle())
        .onDisappear {
            print("\(String(describing: type(of: self))) onDisappear")
            roomCtx.disconnect()
        }
    }
}

@main
struct LiveKitExample: App {

    @StateObject var appCtx = AppContext()

    init() {
        LoggingSystem.bootstrap({ LiveKitLogHandler(label: $0) })
    }

    var body: some Scene {
        WindowGroup {
            RoomContextView()
                .environmentObject(appCtx)
        }
        #if os(macOS)
        .windowStyle(.automatic)
        .windowToolbarStyle(.automatic)
        #endif
    }
}
