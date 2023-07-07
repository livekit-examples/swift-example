import SwiftUI
import LiveKit
import WebRTC

// This class contains the logic to control behavior of the whole app.
final class RoomContext: ObservableObject {

    private let store: ValueStore<Preferences>

    // Used to show connection error dialog
    // private var didClose: Bool = false
    @Published var shouldShowDisconnectReason: Bool = false
    public var latestError: DisconnectReason?

    public let room = ExampleObservableRoom()

    @Published var url: String = "" {
        didSet { store.value.url = url }
    }

    @Published var token: String = "" {
        didSet { store.value.token = token }
    }

    @Published var e2eeKey: String = "" {
        didSet { store.value.e2eeKey = e2eeKey }
    }

    @Published var e2ee: Bool = false {
        didSet { store.value.e2ee = e2ee }
    }

    // RoomOptions
    @Published var simulcast: Bool = true {
        didSet { store.value.simulcast = simulcast }
    }

    @Published var adaptiveStream: Bool = false {
        didSet { store.value.adaptiveStream = adaptiveStream }
    }

    @Published var dynacast: Bool = false {
        didSet { store.value.dynacast = dynacast }
    }

    @Published var reportStats: Bool = false {
        didSet { store.value.reportStats = reportStats }
    }

    // ConnectOptions
    @Published var autoSubscribe: Bool = true {
        didSet { store.value.autoSubscribe = autoSubscribe}
    }

    @Published var publish: Bool = false {
        didSet { store.value.publishMode = publish }
    }

    public init(store: ValueStore<Preferences>) {
        self.store = store
        room.room.add(delegate: self)

        self.url = store.value.url
        self.token = store.value.token
        self.e2ee = store.value.e2ee
        self.e2eeKey = store.value.e2eeKey
        self.simulcast = store.value.simulcast
        self.adaptiveStream = store.value.adaptiveStream
        self.dynacast = store.value.dynacast
        self.reportStats = store.value.reportStats
        self.autoSubscribe = store.value.autoSubscribe
        self.publish = store.value.publishMode

        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = true
        #endif
    }

    deinit {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = false
        #endif
        print("RoomContext.deinit")
    }

    @MainActor
    func connect(entry: ConnectionHistory? = nil) async throws -> Room {

        if let entry = entry {
            url = entry.url
            token = entry.token
            e2ee = entry.e2ee
            e2eeKey = entry.e2eeKey
        }

        let connectOptions = ConnectOptions(
            autoSubscribe: !publish && autoSubscribe, // don't autosubscribe if publish mode
            publishOnlyMode: publish ? "publish_\(UUID().uuidString)" : nil
        )

        var e2eeOptions: E2EEOptions? = nil
        if e2ee {
            let keyProvider = BaseKeyProvider(isSharedKey: true)
            keyProvider.setSharedKey(key: e2eeKey)
            e2eeOptions = E2EEOptions(keyProvider: keyProvider)
        }

        let roomOptions = RoomOptions(
            defaultCameraCaptureOptions: CameraCaptureOptions(
                dimensions: .h1080_169
            ),
            defaultScreenShareCaptureOptions: ScreenShareCaptureOptions(
                dimensions: .h1080_169,
                useBroadcastExtension: true
            ),
            defaultVideoPublishOptions: VideoPublishOptions(
                simulcast: publish ? false : simulcast
            ),
            adaptiveStream: adaptiveStream,
            dynacast: dynacast,
            reportStats: reportStats,
            e2eeOptions: e2eeOptions
        )

        return try await room.room.connect(url,
                                           token,
                                           connectOptions: connectOptions,
                                           roomOptions: roomOptions)
    }

    func disconnect() async throws {
        try await room.room.disconnect()
    }
}

extension RoomContext: RoomDelegate {

    func room(_ room: Room, didUpdate connectionState: ConnectionState, oldValue: ConnectionState) {

        print("Did update connectionState \(oldValue) -> \(connectionState)")

        if case .disconnected(let reason) = connectionState, reason != .user {
            latestError = reason
            DispatchQueue.main.async {
                self.shouldShowDisconnectReason = true
            }
        }

        DispatchQueue.main.async {
            withAnimation {
                self.objectWillChange.send()
            }
        }
    }
}
