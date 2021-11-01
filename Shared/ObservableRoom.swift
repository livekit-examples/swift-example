import SwiftUI
import LiveKit
import OrderedCollections
import AVFoundation

final class ObservableRoom: ObservableObject {

    let room: Room

    @Published private(set) var participants = OrderedDictionary<Sid, ObservableParticipant>() {
        didSet {
            allParticipants = participants
            if let localParticipant = room.localParticipant {
                allParticipants.updateValue(ObservableParticipant(localParticipant),
                                            forKey: localParticipant.sid,
                                            insertingAt: 0)
            }
        }
    }

    @Published private(set) var allParticipants = OrderedDictionary<Sid, ObservableParticipant>()

    @Published private(set) var localVideo: LocalTrackPublication?
    @Published private(set) var localAudio: LocalTrackPublication?

    // This is an example of using VideoCaptureInterceptor for custom frame processing
    let interceptor = VideoCaptureInterceptor { frame, capture in
        print("Captured frame with size:\(frame.width)x\(frame.height) on \(frame.timeStampNs)")
        // For this example, we are not doing anything here and just using the original frame.
        // It's possible to construct a `RTCVideoFrame` and pass it to `capture`.
        capture(frame)
    }

    init(_ room: Room) {
        self.room = room
        room.add(delegate: self)

        if room.remoteParticipants.isEmpty {
            self.participants = [:]
        } else {
            // create initial participants
            for element in room.remoteParticipants {
                self.participants[element.key] = ObservableParticipant(element.value)
            }
        }
    }

    deinit {
        // cameraTrack?.stop()
        room.remove(delegate: self)
    }

    func togglePublishCamera() {

        guard let localParticipant = room.localParticipant else {
            // LocalParticipant should exist if alreadey connected to the room
            print("LocalParticipant doesn't exist")
            return
        }

        if let localVideo = self.localVideo {
            // Try to un-publish the camera
            localParticipant.unpublish(publication: localVideo).then {
                // Update UI
                self.localVideo = nil
            }.catch { error in
                // Failed to un-publish
                print(error)
            }

        } else {
            // Try to get the camera track
            if let track = try? LocalVideoTrack.createCameraTrack(name: "camera",
                                                                  interceptor: interceptor) {
                // We got the camera track, now try to publish
                localParticipant.publishVideoTrack(track: track).then { pub in
                    // Update UI
                    self.localVideo = pub
                }.catch { error in
                    // If failed to publish, stop the track
                    track.stop()
                    print(error)
                }
            }
        }
    }

    func togglePublishMicrophone() {

        guard let localParticipant = room.localParticipant else {
            // LocalParticipant should exist if alreadey connected to the room
            print("LocalParticipant doesn't exist")
            return
        }

        if let localAudio = self.localAudio {
            // Try to un-publish the microphone
            localParticipant.unpublish(publication: localAudio).then {
                // Update UI
                self.localAudio = nil
            }.catch { error in
                // Failed to un-publish
                print(error)
            }

        } else {
            // Try to get the camera track
            let track = LocalAudioTrack.createTrack(name: "microphone")
            // We got the camera track, now try to publish
            localParticipant.publishAudioTrack(track: track).then { pub in
                // Update UI
                self.localAudio = pub
            }.catch { error in
                // If failed to publish, stop the track
                track.stop()
                print(error)
            }
        }

    }
}

extension ObservableRoom: RoomDelegate {

    func room(_ room: Room,
              participantDidJoin participant: RemoteParticipant) {
        DispatchQueue.main.async {
            self.participants[participant.sid] = ObservableParticipant(participant)
        }
    }

    func room(_ room: Room,
              participantDidLeave participant: RemoteParticipant) {
        DispatchQueue.main.async {
            self.participants.removeValue(forKey: participant.sid)
        }
    }
}
