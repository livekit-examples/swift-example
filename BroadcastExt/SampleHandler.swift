import ReplayKit
import LiveKit
import WebRTC
import Promises
import os.log

let logger = OSLog(subsystem: "io.livekit.example.screen-broadcaster",
                   category: "Broadcaster")

class SampleHandler: RPBroadcastSampleHandler {

    static let ipcName = "group.livekit-example.broadcast.buffer-ipc"
    let ipcClient = IPCClient()

    //    var room: Room?
    //    var videoTrack: LocalVideoTrack?

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {

        ipcClient.connect(SampleHandler.ipcName)
        os_log("broadcast started", log: logger, type: .debug)
        if ipcClient.connected {
            os_log("ipc connected", log: logger, type: .debug)
        } else {
            super.finishBroadcastWithError(NSError(domain: "", code: 0, userInfo: nil))
            os_log("ipc not connected", log: logger, type: .debug)
        }
        //        let options = ConnectOptions(
        //            // do not subscribe since this is for publish only
        //            autoSubscribe: false
        //        )
        //
        //        LiveKit.connect("wss://rtc.unxpected.co.jp",
        //                        "",
        //                        options: options,
        //                        delegate: self).then { room in
        //            self.room = room
        //            os_log("connected to room", log: logger, type: .debug)
        //            do {
        //                let track = try LocalVideoTrack.createReplayKitTrack(name: "screen")
        //                self.videoTrack = track
        //
        //                room.localParticipant?.publishVideoTrack(track: track).then({ _ in
        //                    os_log("did publish video track", log: logger, type: .debug)
        //                })
        //            } catch _ {
        //                os_log("failed to publish local track", log: logger, type: .error)
        //            }
        //        }
    }

    override func broadcastPaused() {
        // User has requested to pause the broadcast. Samples will stop being delivered.

        os_log("broadcast paused", log: logger, type: .debug)
    }

    override func broadcastResumed() {
        // User has requested to resume the broadcast. Samples delivery will resume.

        os_log("broadcast resumed", log: logger, type: .debug)
    }

    override func broadcastFinished() {
        // User has requested to finish the broadcast.
        os_log("broadcast finished", log: logger, type: .debug)

        ipcClient.close()
        //        guard let room = room else {
        //            return
        //        }
        //
        //        room.disconnect()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {

        os_log("process sample buffer", log: logger, type: .debug)

        switch sampleBufferType {
        case RPSampleBufferType.video:

            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
            }

            // attempt to determine rotation information if buffer is coming from ReplayKit
            var rotation: RTCVideoRotation?
            if #available(macOS 11.0, *) {
                // Check rotation tags. Extensions see these tags, but `RPScreenRecorder` does not appear to set them.
                // On iOS 12.0 and 13.0 rotation tags (other than up) are set by extensions.
                if let sampleOrientation = CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil),
                   let coreSampleOrientation = sampleOrientation.uint32Value {
                    rotation = CGImagePropertyOrientation(rawValue: coreSampleOrientation)?.toRTCRotation()
                }
            }

            let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let timeStampNs = UInt64(CMTimeGetSeconds(timeStamp) * Double(NSEC_PER_SEC))

            let pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer)

            let message = IPCMessage.with {
                $0.buffer = IPCMessage.Buffer.with({
                    $0.timestampNs = timeStampNs
                    $0.buffer = Data(pixelBuffer: imageBuffer)
                    $0.video = .with({
                        $0.format = pixelFormat
                        $0.rotation = UInt32(rotation?.rawValue ?? 0)
                        $0.width = UInt32(CVPixelBufferGetWidth(imageBuffer))
                        $0.height = UInt32(CVPixelBufferGetHeight(imageBuffer))
                    })
                })
            }

            guard let protoData = try? message.serializedData() else { return }
            ipcClient.send(protoData, messageId: 1)

        default: break
        }
    }
}
