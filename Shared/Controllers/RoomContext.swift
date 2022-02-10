import SwiftUI
import LiveKit
import WebRTC
import Promises

// This class contains the logic to control behavior of the whole app.
final class RoomContext: ObservableObject {

    private let store: SecureStore<SecureStoreKeys>

    // Used to show connection error dialog
    // private var didClose: Bool = false
    @Published var shouldShowError: Bool = false
    public var latestError: Error?

    public let room = ExampleObservableRoom()
    public var connectionState: ConnectionState {
        room.room.connectionState
    }

    @Published var url: String {
        didSet { store.set(.url, value: url) }
    }

    @Published var token: String {
        didSet { store.set(.token, value: token) }
    }

    // RoomOptions
    @Published var simulcast: Bool {
        didSet { store.set(.simulcast, value: simulcast) }
    }

    @Published var adaptiveStream: Bool {
        didSet { store.set(.adaptiveStream, value: adaptiveStream) }
    }

    @Published var dynacast: Bool {
        didSet { store.set(.dynacast, value: dynacast) }
    }

    // ConnectOptions
    @Published var autoSubscribe: Bool {
        didSet { store.set(.autoSubscribe, value: autoSubscribe) }
    }

    @Published var publish: Bool {
        didSet { store.set(.publishMode, value: publish) }
    }

    public init(store: SecureStore<SecureStoreKeys>) {
        self.store = store
        self.url = store.get(.url) ?? ""
        self.token = store.get(.token) ?? ""
        self.simulcast = store.get(.simulcast) ?? true
        self.adaptiveStream = store.get(.adaptiveStream) ?? false
        self.dynacast = store.get(.dynacast) ?? false
        self.autoSubscribe = store.get(.autoSubscribe) ?? true
        self.publish = store.get(.publishMode) ?? false
        room.room.add(delegate: self)
    }

    func connect(entry: ConnectionHistory? = nil) -> Promise<Room> {

        if let entry = entry {
            url = entry.url
            token = entry.token
        }

        let connectOptions = ConnectOptions(
            autoSubscribe: !publish && autoSubscribe, // don't autosubscribe if publish mode
            publish: publish ? "publish_\(UUID().uuidString)" : nil
        )

        let roomOptions = RoomOptions(
            // Pass the simulcast option
            defaultVideoPublishOptions: VideoPublishOptions(
                simulcast: publish ? false : simulcast
            ),
            adaptiveStream: adaptiveStream,
            dynacast: dynacast
        )

        return room.room.connect(url,
                                 token,
                                 connectOptions: connectOptions,
                                 roomOptions: roomOptions)
    }

    func disconnect() {
        room.room.disconnect()
    }
}

extension RoomContext: RoomDelegate {

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
