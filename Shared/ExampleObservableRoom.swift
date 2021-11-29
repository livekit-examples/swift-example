import SwiftUI
import LiveKit
import OrderedCollections
import AVFoundation

import WebRTC
import CoreImage.CIFilterBuiltins
import ReplayKit

class ExampleObservableRoom: ObservableRoom {

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

    // the name to use for ipc
    static let ipcName = "group.livekit-example.broadcast.buffer-ipc"

    var ipcPub: LocalTrackPublication?

    func toggleScreenEnabled(_ source: ScreenShareSource? = nil) {

        guard let localParticipant = room.localParticipant else {
            // LocalParticipant should exist if alreadey connected to the room
            print("LocalParticipant doesn't exist")
            return
        }

        localParticipant.setScreenShare(enabled: !localParticipant.isScreenShareEnabled(), source: source).then { publication in
            self.localScreen = publication
        }

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
        //        #elseif os(macOS)
        //        if let pub = ipcPub {
        //            //
        //            localParticipant.unpublish(publication: pub).then {
        //                self.ipcPub = nil
        //            }
        //
        //        } else {
        //
        //            let track = LocalVideoTrack.createMacOSScreenShareTrack(source: source)
        //            localParticipant.publishVideoTrack(track: track).then { pub in
        //                self.ipcPub = pub
        //            }
        //        }
        //        #endif
    }

    func toggleCameraPosition() {
        guard let publication = localVideo,
              let track = publication.track as? LocalVideoTrack,
              let cameraCapturer = track.capturer as? CameraCapturer else {
            print("Track or Capturer doesn't exist")
            return
        }

        cameraCapturer.switchCameraPosition()
    }

    func toggleCameraEnabled() {

        guard let localParticipant = room.localParticipant else {
            // LocalParticipant should exist if alreadey connected to the room
            print("LocalParticipant doesn't exist")
            return
        }

        localParticipant.setCamera(enabled: !localParticipant.isCameraEnabled(),
                                   interceptor: interceptor).then { publication in
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
        //            //            if let track = try? LocalVideoTrack.createCameraTrack(name: "camera",
        //            //                                                                  interceptor: interceptor) {
        //            let track = LocalVideoTrack.createBufferTrack(name: "screen")
        //            // We got the camera track, now try to publish
        //            localParticipant.publishVideoTrack(track: track).then { pub in
        //                // Update UI
        //                self.localVideo = pub
        //            }.catch { error in
        //                // If failed to publish, stop the track
        //                track.stop()
        //                print(error)
        //            }
        //        }

    }

    func toggleMicrophoneEnabled() {

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
