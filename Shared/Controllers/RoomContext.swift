import SwiftUI
import LiveKit
import WebRTC

// This class contains the logic to control behavior of the whole app.
final class RoomContext: ObservableObject {

    let jsonEncoder = JSONEncoder()
    let jsonDecoder = JSONDecoder()

    private let store: ValueStore<Preferences>

    // Used to show connection error dialog
    // private var didClose: Bool = false
    @Published var shouldShowDisconnectReason: Bool = false
    public var latestError: DisconnectReason?

    public let room = Room()

    @Published var url: String = "" {
        didSet { store.value.url = url }
    }

    @Published var token: String = "" {
        didSet { store.value.token = token }
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

    @Published var focusParticipant: Participant?

    @Published var showMessagesView: Bool = false
    @Published var messages: [ExampleRoomMessage] = []

    @Published var textFieldString: String = ""

    public init(store: ValueStore<Preferences>) {
        self.store = store
        room.add(delegate: self)

        self.url = store.value.url
        self.token = store.value.token
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
        }

        let connectOptions = ConnectOptions(
            autoSubscribe: !publish && autoSubscribe, // don't autosubscribe if publish mode
            publishOnlyMode: publish ? "publish_\(UUID().uuidString)" : nil
        )

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
            reportStats: reportStats
        )

        return try await room.connect(url,
                                           token,
                                           connectOptions: connectOptions,
                                           roomOptions: roomOptions)
    }

    func disconnect() async throws {
        try await room.disconnect()
    }


    func sendMessage() {

        guard let localParticipant = room.localParticipant else {
            print("LocalParticipant doesn't exist")
            return
        }

        // Make sure the message is not empty
        guard !textFieldString.isEmpty else { return }

        let roomMessage = ExampleRoomMessage(messageId: UUID().uuidString,
                                             senderSid: localParticipant.sid,
                                             senderIdentity: localParticipant.identity,
                                             text: textFieldString)
        textFieldString = ""
        messages.append(roomMessage)

        Task {
            do {
                let json = try jsonEncoder.encode(roomMessage)
                try await localParticipant.publish(data: json)
            } catch let error {
                print("Failed to encode data \(error)")
            }

        }
    }
    
    //
    //    #if os(iOS)
    //    func toggleScreenShareEnablediOS() {
    //        toggleScreenShareEnabled()
    //    }
    //    #elseif os(macOS)
    //    func toggleScreenShareEnabledMacOS(screenShareSource: MacOSScreenCaptureSource? = nil) {
    //
    //        guard let localParticipant = room.localParticipant else {
    //            print("LocalParticipant doesn't exist")
    //            return
    //        }
    //
    //        guard !screenShareTrackState.isBusy else {
    //            print("screenShareTrackState is .busy")
    //            return
    //        }
    //
    //        if case .published(let track) = screenShareTrackState {
    //
    //            DispatchQueue.main.async {
    //                self.screenShareTrackState = .busy(isPublishing: false)
    //            }
    //
    //            localParticipant.unpublish(publication: track).then { _ in
    //                DispatchQueue.main.async {
    //                    self.screenShareTrackState = .notPublished()
    //                }
    //            }
    //        } else {
    //
    //            guard let source = screenShareSource else { return }
    //
    //            print("selected source: \(source)")
    //
    //            DispatchQueue.main.async {
    //                self.screenShareTrackState = .busy(isPublishing: true)
    //            }
    //
    //            let track = LocalVideoTrack.createMacOSScreenShareTrack(source: source)
    //            localParticipant.publishVideoTrack(track: track).then { publication in
    //                DispatchQueue.main.async {
    //                    self.screenShareTrackState = .published(publication)
    //                }
    //            }.catch { error in
    //                DispatchQueue.main.async {
    //                    self.screenShareTrackState = .notPublished(error: error)
    //                }
    //            }
    //        }
    //    }
    //    #endif
    //
//        func unpublishAll() async throws {
//            guard let localParticipant = self.room.localParticipant else { return }
//            try await localParticipant.unpublishAll()
//            Task { @MainActor in
////                self.cameraTrackState = .notPublished()
////                self.microphoneTrackState = .notPublished()
////                self.screenShareTrackState = .notPublished()
//            }
//        }
    //
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
