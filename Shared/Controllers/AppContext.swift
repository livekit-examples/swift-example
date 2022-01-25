import SwiftUI
import LiveKit
import WebRTC

// This class contains the logic to control behavior of the whole app.
final class AppContextCtrl: ObservableObject {
    // Used to show connection error dialog
    // private var didClose: Bool = false
    @Published var shouldShowError: Bool = false
    public var latestError: Error?

    public let room = ExampleObservableRoom()
    public var connectionState: ConnectionState {
        room.room.connectionState
    }

    public init() {
        room.room.add(delegate: self)
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

        room.room.connect(url,
                          token,
                          connectOptions: connectOptions,
                          roomOptions: roomOptions)
    }

    func disconnect() {
        room.room.disconnect()
    }
}

extension AppContextCtrl: RoomDelegate {

    func room(_ room: Room, didUpdate connectionState: ConnectionState) {
        print("Did update connectionState \(connectionState) \(room.connectionState)")
        DispatchQueue.main.async {
            withAnimation {
                self.objectWillChange.send()
            }
        }
    }
}
