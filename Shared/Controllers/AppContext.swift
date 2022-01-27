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

    @AppStorage("url") var url: String = ""
    @AppStorage("token") var token: String = ""
    @AppStorage("simulcast") var simulcast: Bool = true
    @AppStorage("publish") var publish: Bool = false
    @AppStorage("connectionHistory") var connectionHistory = ConnectionHistory()

    public init() {
        room.room.add(delegate: self)
    }

    func connect(entry: ConnectionHistoryEntry? = nil) {

        if let entry = entry {
            url = entry.url
            token = entry.token
        }

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
                          roomOptions: roomOptions).then { room in

                            // add successful connection to history
                            self.connectionHistory.update(room: room)
                          }
    }

    func disconnect() {
        room.room.disconnect()
    }
}

extension AppContextCtrl: RoomDelegate {

    func room(_ room: Room, didUpdate connectionState: ConnectionState) {
        print("Did update connectionState \(connectionState) \(room.connectionState)")

        if let error = connectionState.disconnectedWithError {
            latestError = error
            DispatchQueue.main.async {
                self.shouldShowError = true
            }
        }

        DispatchQueue.main.async {
            withAnimation {
                self.objectWillChange.send()
            }
        }
    }
}
