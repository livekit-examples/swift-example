import SwiftUI
import LiveKit
import Logging
import WebRTC

// This class contains the logic to control behavior of the whole app.
// The instance is attached to the root using `environmentObject`,
// so it can be accessed anywhere by using `@EnvironmentObject`.
final class AppCtrl: ObservableObject {

    // Singleton pattern
    public static let shared = AppCtrl()

    // Used to show connection error dialog
    // private var didClose: Bool = false
    @Published var shouldShowError: Bool = false
    public var latestError: Error?

    @Published private(set) var connectionState: ConnectionState = .disconnected() {
        didSet {
            // Don't do anything if value is same
            guard oldValue != connectionState else { return }

            if case .disconnected(let error) = connectionState {
                room = nil

                if error != nil {
                    latestError = error
                    shouldShowError = true
                }
            }
        }
    }

    @Published private(set) var room: Room?

    private init() {
        LoggingSystem.bootstrap({ LiveKitLogHandler(label: $0) })
    }

    func connect(url: String,
                 token: String,
                 simulcast: Bool = true,
                 publish: Bool = false) {

        print("Connecting to Room...")

        let connectOptions = ConnectOptions(
            publish: publish ? "publish_\(UUID().uuidString)" : nil
        )

        let roomOptions = RoomOptions(
            // Pass the simulcast option
            defaultVideoPublishOptions: VideoPublishOptions(simulcast: simulcast)
        )

        LiveKit.connect(url,
                        token,
                        delegate: self,
                        connectOptions: connectOptions,
                        roomOptions: roomOptions).then { room in
                            print("Did connect to Room, name: \(room.name ?? "(no name)")")
                            DispatchQueue.main.async {
                                self.room = room
                            }
                        }.catch { error in
                            print("\(String(describing: self)) Failed to connect to room with error: \(error)")
                            DispatchQueue.main.async {
                                self.connectionState = .disconnected(error: error)
                            }
                        }
    }

    func disconnect() {
        room?.disconnect()
        room = nil
    }
}

extension AppCtrl: RoomDelegate {

    func room(_ room: Room, didUpdate connectionState: ConnectionState) {

        print("Did update connectionState \(connectionState)")

        DispatchQueue.main.async {
            // UI will update according to the connectionState
            withAnimation {
                self.connectionState = connectionState
            }
        }
    }
}
