import SwiftUI
import LiveKit
import AVFoundation

import WebRTC
import CoreImage.CIFilterBuiltins
import ReplayKit

extension ObservableParticipant {

    public var mainVideoPublication: TrackPublication? {
        firstScreenSharePublication ?? firstCameraPublication
    }

    public var mainVideoTrack: VideoTrack? {
        firstScreenShareVideoTrack ?? firstCameraVideoTrack
    }

    public var subVideoTrack: VideoTrack? {
        firstScreenShareVideoTrack != nil ? firstCameraVideoTrack : nil
    }
}

struct ExampleRoomMessage: Identifiable, Equatable, Hashable, Codable {
    // Identifiable protocol needs param named id
    var id: String {
        messageId
    }

    // message id
    let messageId: String

    let senderSid: String
    let senderIdentity: String
    let text: String

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.messageId == rhs.messageId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(messageId)
    }
}

class ExampleObservableRoom: ObservableRoom {

    let queue = DispatchQueue(label: "example.observableroom")

    let jsonEncoder = JSONEncoder()
    let jsonDecoder = JSONDecoder()

    @Published var focusParticipant: ObservableParticipant?

    @Published var showMessagesView: Bool = false
    @Published var messages: [ExampleRoomMessage] = []

    @Published var textFieldString: String = ""

    override init(_ room: Room = Room()) {
        super.init(room)
        room.add(delegate: self)
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

        do {
            let json = try jsonEncoder.encode(roomMessage)

            localParticipant.publishData(data: json).then {
                print("did send data")
            }.catch { error in
                print("failed to send data \(error)")
            }

        } catch let error {
            print("Failed to encode data \(error)")
        }
    }

    #if os(iOS)
    func toggleScreenShareEnablediOS() {
        toggleScreenShareEnabled()
    }
    #elseif os(macOS)
    func toggleScreenShareEnabledMacOS(screenShareSource: MacOSScreenCaptureSource? = nil) {

        guard let localParticipant = room.localParticipant else {
            print("LocalParticipant doesn't exist")
            return
        }

        guard !screenShareTrackState.isBusy else {
            print("screenShareTrackState is .busy")
            return
        }

        if case .published(let track) = screenShareTrackState {

            DispatchQueue.main.async {
                self.screenShareTrackState = .busy(isPublishing: false)
            }

            localParticipant.unpublish(publication: track).then { _ in
                DispatchQueue.main.async {
                    self.screenShareTrackState = .notPublished()
                }
            }
        } else {

            guard let source = screenShareSource else { return }

            print("selected source: \(source)")

            DispatchQueue.main.async {
                self.screenShareTrackState = .busy(isPublishing: true)
            }

            let track = LocalVideoTrack.createMacOSScreenShareTrack(source: source)
            localParticipant.publishVideoTrack(track: track).then { publication in
                DispatchQueue.main.async {
                    self.screenShareTrackState = .published(publication)
                }
            }.catch { error in
                DispatchQueue.main.async {
                    self.screenShareTrackState = .notPublished(error: error)
                }
            }
        }
    }
    #endif

    func unpublishAll() async throws {
        guard let localParticipant = self.room.localParticipant else { return }
        try await localParticipant.unpublishAll()
        Task { @MainActor in
            self.cameraTrackState = .notPublished()
            self.microphoneTrackState = .notPublished()
            self.screenShareTrackState = .notPublished()
        }
    }

    // MARK: - RoomDelegate

    override func room(_ room: Room, didUpdate connectionState: ConnectionState, oldValue: ConnectionState) {

        super.room(room, didUpdate: connectionState, oldValue: oldValue)

        if case .disconnected = connectionState {
            DispatchQueue.main.async {
                // Reset state
                self.focusParticipant = nil
                self.showMessagesView = false
                self.textFieldString = ""
                self.messages.removeAll()
                self.objectWillChange.send()
            }
        }
    }

    override func room(_ room: Room,
                       participantDidLeave participant: RemoteParticipant) {
        DispatchQueue.main.async {
            // self.participants.removeValue(forKey: participant.sid)
            if let focusParticipant = self.focusParticipant,
               focusParticipant.sid == participant.sid {
                self.focusParticipant = nil
            }
            self.objectWillChange.send()
        }
    }

    override func room(_ room: Room,
                       participant: RemoteParticipant?, didReceive data: Data) {

        print("did receive data \(data)")

        do {
            let roomMessage = try jsonDecoder.decode(ExampleRoomMessage.self, from: data)
            // Update UI from main queue
            DispatchQueue.main.async {
                withAnimation {
                    // Add messages to the @Published messages property
                    // which will trigger the UI to update
                    self.messages.append(roomMessage)
                    // Show the messages view when new messages arrive
                    self.showMessagesView = true
                }
            }

        } catch let error {
            print("Failed to decode data \(error)")
        }
    }

    override func room(_ room: Room, participant: RemoteParticipant,
                       didPublish publication: RemoteTrackPublication) {

        print("participant:\(participant) didPublish:\(publication)")

        Task.detached { @MainActor in
            self.objectWillChange.send()
        }
    }

    override func room(_ room: Room, participant: RemoteParticipant,
                       didUnpublish publication: RemoteTrackPublication) {

        print("participant:\(participant) didUnpublish:\(publication)")

        Task.detached { @MainActor in
            self.objectWillChange.send()
        }
    }
}
