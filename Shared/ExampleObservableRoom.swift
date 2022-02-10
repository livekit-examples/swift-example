import SwiftUI
import LiveKit
import OrderedCollections
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

    func toggleScreenShareEnabled(screenShareSource: ScreenShareSource? = nil) {

        #if os(iOS)
        // return toggleScreenShareEnabled()
        // Experimental iOS screen share

        RPSystemBroadcastPickerView.show(for: "io.livekit.example.Multiplatform-SwiftUI.BroadcastExt",
                                         showsMicrophoneButton: false)

        if let ud = UserDefaults(suiteName: "group.livekit-example.broadcast") {
            ud.set(room.url, forKey: "url")
            ud.set(room.token, forKey: "token")
        }

        #elseif os(macOS)

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

            DispatchQueue.main.async {
                self.screenShareTrackState = .busy(isPublishing: true)
            }

            let track = LocalVideoTrack.createMacOSScreenShareTrack(source: screenShareSource ?? .mainDisplay)
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
        #endif
    }

    // MARK: - RoomDelegate

    override func room(_ room: Room, didUpdate connectionState: ConnectionState) {
        super.room(room, didUpdate: connectionState)
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
}
