import SwiftUI
import LiveKit
import Logging
import WebRTC

// This class contains the logic to control behavior of the whole app.
// The instance is attached to the root using `environmentObject`,
// so it can be accessed anywhere by using `@EnvironmentObject`.
final class AppCtrl: ObservableObject {

    // Singleton pattern
    public static var shared = AppCtrl()

    // Used to show connection error dialog
    // private var didClose: Bool = false
    @Published var shouldShowError: Bool = false
    public var latestError: Error?

    public let room = Room()
    public var connectionState: ConnectionState {
        room.connectionState
    }

    private init() {
        LoggingSystem.bootstrap({ LiveKitLogHandler(label: $0) })
        room.add(delegate: self)
    }

    func connect(url: String,
                 token: String,
                 simulcast: Bool = true,
                 publish: Bool = false) {

        let connectOptions = ConnectOptions(
            publish: publish ? "publish_\(UUID().uuidString)" : nil
        )

        let roomOptions = RoomOptions(
            // Pass the simulcast option
            defaultVideoPublishOptions: VideoPublishOptions(simulcast: simulcast)
        )

        room.connect(url,
                     token,
                     connectOptions: connectOptions,
                     roomOptions: roomOptions)
    }

    func disconnect() {
        room.disconnect()
    }
}

extension AppCtrl: RoomDelegate {

    func room(_ room: Room, didUpdate connectionState: ConnectionState) {
        print("Did update connectionState \(connectionState) \(room.connectionState)")
        DispatchQueue.main.async {
            withAnimation {
                self.objectWillChange.send()
            }
        }
    }
}
