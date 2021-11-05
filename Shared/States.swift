import SwiftUI
import LiveKit

extension AppCtrl: RoomDelegate {

    func room(_ room: Room, didUpdate connectionState: ConnectionState) {

        print("connectionState didUpdate \(connectionState)")

        // UI will update according to the connectionState
        withAnimation {
            self.connectionState = connectionState
        }
    }
}

final class AppCtrl: ObservableObject {

    public static let shared = AppCtrl()

    @Published var shouldShowError: Bool = false
        
    @Published private(set) var connectionState: ConnectionState = .disconnected() {
        didSet {
            if case .disconnected(let error) = connectionState {
                room = nil
                if error != nil {
                    // error is not nil, show an alert
                    shouldShowError = true
                }
            }
        }
    }

    @Published private(set) var room: Room?

    func connect(url: String, token: String, simulcast: Bool = true) {

        print("connecting...")

        let options = ConnectOptions(defaultVideoPublishOptions: LocalVideoTrackPublishOptions(simulcast: simulcast))

        LiveKit.connect(url,
                        token,
                        options: options, delegate: self).then { room in
                            print("did connect! \(room)")
                            self.room = room
                        }.catch { error in
                            print("did throw error \(error)")
                            self.connectionState = .disconnected(error)
                        }
    }

    func disconnect() {
        room?.disconnect()
    }
}
