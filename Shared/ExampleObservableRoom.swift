import SwiftUI
import LiveKit
import OrderedCollections
import AVFoundation

import WebRTC
import CoreImage.CIFilterBuiltins
import ReplayKit

extension ObservableParticipant {

    public var mainVideoTrack: VideoTrack? {
        firstScreenShareVideoTrack ?? firstCameraVideoTrack
    }

    public var subVideoTrack: VideoTrack? {
        firstScreenShareVideoTrack != nil ? firstCameraVideoTrack : nil
    }
}

struct RoomMessage: Identifiable, Equatable, Hashable, Codable {
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

    let bgName: [Background: String] = [
        .office: "bg-1",
        .space: "bg-2",
        .thailand: "bg-3"
    ]

    enum Background {
        case none
        case office
        case space
        case thailand
    }

    @Published var focusParticipant: ObservableParticipant?

    @Published var showMessagesView: Bool = false
    @Published var messages: [RoomMessage] = []

    @Published var textFieldString: String = ""

    @Published var background: Background = .none {
        didSet {
            #if swift(>=5.5)
            if #available(iOS 15, macOS 12, *) {
                DispatchQueue.main.async {
                    if let name = self.bgName[self.background] {
                        self.bgSwapper.image = CIImage(named: name)
                    } else {
                        self.bgSwapper.image = nil
                    }
                }
            }
            #endif
        }
    }

    override init(_ room: Room) {
        super.init(room)
        room.add(delegate: self)
    }

    private var _bgSwapper: Any?
    #if swift(>=5.5)
    @available(iOS 15, macOS 12, *)
    var bgSwapper: BackgroundSwapper {
        get {
            _bgSwapper = _bgSwapper ?? BackgroundSwapper()
            return _bgSwapper as! BackgroundSwapper
        }
    }
    #endif

    // This is an example of using VideoCaptureInterceptor for custom frame processing
    lazy var interceptor = VideoCaptureInterceptor { frame, capture in
        // print("Captured frame with size:\(frame.width)x\(frame.height) on \(frame.timeStampNs)")
        // For this example, we are not doing anything here and just using the original frame.
        // It's possible to construct a `RTCVideoFrame` and pass it to `capture`.
        #if swift(>=5.5)
        if #available(iOS 15, macOS 12, *) {
            self.bgSwapper.process(frame: frame, capture: capture)
        } else {
            capture(frame)
        }
        #endif
    }

    func sendMessage() {

        guard let localParticipant = room.localParticipant else {
            // LocalParticipant should exist if alreadey connected to the room
            print("LocalParticipant doesn't exist")
            return
        }

        // Make sure the message is not empty
        guard !textFieldString.isEmpty else { return }

        let roomMessage = RoomMessage(messageId: UUID().uuidString,
                                      senderSid: localParticipant.sid,
                                      senderIdentity: localParticipant.identity ?? "(\(localParticipant.sid)",
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

    // the name to use for ipc
    //    static let ipcName = "group.livekit-example.broadcast.buffer-ipc"

    //    var screenSharePublication: LocalTrackPublication?

    func toggleScreenEnabled(_ source: ScreenShareSource? = nil) {

        guard let localParticipant = room.localParticipant else {
            // LocalParticipant should exist if alreadey connected to the room
            print("LocalParticipant doesn't exist")
            return
        }

        #if os(macOS)
        if let publication = self.localScreen {
            localParticipant.unpublish(publication: publication).then {
                DispatchQueue.main.async {
                    self.localScreen = nil
                }
            }
        } else {
            let track = LocalVideoTrack.createMacOSScreenShareTrack(source: source ?? .mainDisplay)
            localParticipant.publishVideoTrack(track: track).then { publication in
                DispatchQueue.main.async {
                    self.localScreen = publication
                }
            }
        }
        #endif

        //        #if os(iOS)
        //
        //        if let pub = ipcPub {
        //            //
        //            localParticipant.unpublish(publication: pub).then {
        //                self.ipcPub = nil
        //            }
        //
        //        } else {
        //            let track = LocalVideoTrack.createIPCTrack(ipcName: ExampleObservableRoom.ipcName)
        //            localParticipant.publishVideoTrack(track: track).then { pub in
        //                self.ipcPub = pub
        //            }
        //        }
        //
        //        RPSystemBroadcastPickerView.show(for: "io.livekit.example.Multiplatform-SwiftUI.BroadcastExt",
        //                                         showsMicrophoneButton: false)
        //

    }

    override func room(_ room: Room,
                       participantDidLeave participant: RemoteParticipant) {
        DispatchQueue.main.async {
            self.participants.removeValue(forKey: participant.sid)
            if let focusParticipant = self.focusParticipant,
               focusParticipant.sid == participant.sid {
                self.focusParticipant = nil
            }
        }
    }

    override func room(_ room: Room, participant: RemoteParticipant?, didReceive data: Data) {

        print("did receive data \(data)")

        do {
            let roomMessage = try jsonDecoder.decode(RoomMessage.self, from: data)
            // Update UI from main queue
            DispatchQueue.main.async {
                // Add messages to the @Published messages property
                // which will trigger the UI to update
                self.messages.append(roomMessage)
                // Show the messages view when new messages arrive
                self.showMessagesView = true
            }

        } catch let error {
            print("Failed to decode data \(error)")
        }
    }
}
