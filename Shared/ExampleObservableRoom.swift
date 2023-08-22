import SwiftUI
import LiveKit
import AVFoundation

import WebRTC
import CoreImage.CIFilterBuiltins
import ReplayKit

extension Participant {

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

//class ExampleObservableRoom: ObservableRoom {
//
//    let queue = DispatchQueue(label: "example.observableroom")
//
//    let jsonEncoder = JSONEncoder()
//    let jsonDecoder = JSONDecoder()
//
//    @Published var focusParticipant: ObservableParticipant?
//
//    @Published var showMessagesView: Bool = false
//    @Published var messages: [ExampleRoomMessage] = []
//
//    @Published var textFieldString: String = ""
//
//    override init(_ room: Room = Room()) {
//        super.init(room)
//        room.add(delegate: self)
//    }
//
//    // MARK: - RoomDelegate
//
//    override func room(_ room: Room, didUpdate connectionState: ConnectionState, oldValue: ConnectionState) {
//
//        super.room(room, didUpdate: connectionState, oldValue: oldValue)
//
//        if case .disconnected = connectionState {
//            DispatchQueue.main.async {
//                // Reset state
//                self.focusParticipant = nil
//                self.showMessagesView = false
//                self.textFieldString = ""
//                self.messages.removeAll()
//                self.objectWillChange.send()
//            }
//        }
//    }
//
//    override func room(_ room: Room,
//                       participantDidLeave participant: RemoteParticipant) {
//        DispatchQueue.main.async {
//            // self.participants.removeValue(forKey: participant.sid)
//            if let focusParticipant = self.focusParticipant,
//               focusParticipant.sid == participant.sid {
//                self.focusParticipant = nil
//            }
//            self.objectWillChange.send()
//        }
//    }
//
//    override func room(_ room: Room,
//                       participant: RemoteParticipant?, didReceive data: Data) {
//
//        print("did receive data \(data)")
//
//        do {
//            let roomMessage = try jsonDecoder.decode(ExampleRoomMessage.self, from: data)
//            // Update UI from main queue
//            DispatchQueue.main.async {
//                withAnimation {
//                    // Add messages to the @Published messages property
//                    // which will trigger the UI to update
//                    self.messages.append(roomMessage)
//                    // Show the messages view when new messages arrive
//                    self.showMessagesView = true
//                }
//            }
//
//        } catch let error {
//            print("Failed to decode data \(error)")
//        }
//    }
//
//    override func room(_ room: Room, participant: RemoteParticipant,
//                       didPublish publication: RemoteTrackPublication) {
//
//        print("participant:\(participant) didPublish:\(publication)")
//
//        Task.detached { @MainActor in
//            self.objectWillChange.send()
//        }
//    }
//
//    override func room(_ room: Room, participant: RemoteParticipant,
//                       didUnpublish publication: RemoteTrackPublication) {
//
//        print("participant:\(participant) didUnpublish:\(publication)")
//
//        Task.detached { @MainActor in
//            self.objectWillChange.send()
//        }
//    }
//}
