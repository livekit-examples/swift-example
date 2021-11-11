import SwiftUI
import LiveKit
import OrderedCollections
import AVFoundation

import WebRTC
import CoreImage.CIFilterBuiltins

final class ExampleObservableRoom: ObservableRoom {

    @Published var backgroundImage: CIImage? {
        didSet {
            if #available(iOS 15, macOS 12, *) {
                bgSwapper.image = backgroundImage
            }
        }
    }

    private var _bgSwapper: Any?
    @available(iOS 15, macOS 12, *)
    var bgSwapper: BackgroundSwapper {
        get {
            _bgSwapper = _bgSwapper ?? BackgroundSwapper()
            return _bgSwapper as! BackgroundSwapper
        }
    }

    // This is an example of using VideoCaptureInterceptor for custom frame processing
    lazy var interceptor = VideoCaptureInterceptor { frame, capture in
        // print("Captured frame with size:\(frame.width)x\(frame.height) on \(frame.timeStampNs)")
        // For this example, we are not doing anything here and just using the original frame.
        // It's possible to construct a `RTCVideoFrame` and pass it to `capture`.
        if #available(iOS 15, macOS 12, *) {
            self.bgSwapper.process(frame: frame, capture: capture)
        } else {
            capture(frame)
        }
    }

    func togglePublishCamera() {

        guard let localParticipant = room.localParticipant else {
            // LocalParticipant should exist if alreadey connected to the room
            print("LocalParticipant doesn't exist")
            return
        }

        localParticipant.setCamera(enabled: !localParticipant.isCameraEnabled()).then { publication in
            self.localVideo = publication
        }

        //
        // The following code is an example how to publish without using the simplified apis
        //
        //        if let localVideo = self.localVideo {
        //            // Try to un-publish the camera
        //            localParticipant.unpublish(publication: localVideo).then {
        //                // Update UI
        //                self.localVideo = nil
        //            }.catch { error in
        //                // Failed to un-publish
        //                print(error)
        //            }
        //
        //        } else {
        //            // Try to get the camera track
        //            if let track = try? LocalVideoTrack.createCameraTrack(name: "camera",
        //                                                                  interceptor: interceptor) {
        //                // We got the camera track, now try to publish
        //                localParticipant.publishVideoTrack(track: track).then { pub in
        //                    // Update UI
        //                    self.localVideo = pub
        //                }.catch { error in
        //                    // If failed to publish, stop the track
        //                    track.stop()
        //                    print(error)
        //                }
        //            }
        //        }
    }

    func togglePublishMicrophone() {

        guard let localParticipant = room.localParticipant else {
            // LocalParticipant should exist if alreadey connected to the room
            print("LocalParticipant doesn't exist")
            return
        }

        localParticipant.setMicrophone(enabled: !localParticipant.isMicrophoneEnabled()).then { publication in
            self.localAudio = publication
        }

        //
        // The following code is an example how to publish without using the simplified apis
        //
        //        if let localAudio = self.localAudio {
        //            // Try to un-publish the microphone
        //            localParticipant.unpublish(publication: localAudio).then {
        //                // Update UI
        //                self.localAudio = nil
        //            }.catch { error in
        //                // Failed to un-publish
        //                print(error)
        //            }
        //
        //        } else {
        //            // Try to get the camera track
        //            let track = LocalAudioTrack.createTrack(name: "microphone")
        //            // We got the camera track, now try to publish
        //            localParticipant.publishAudioTrack(track: track).then { pub in
        //                // Update UI
        //                self.localAudio = pub
        //            }.catch { error in
        //                // If failed to publish, stop the track
        //                track.stop()
        //                print(error)
        //            }
        //        }

    }
}
