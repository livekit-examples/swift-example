import ReplayKit
import LiveKit
import WebRTC
import Promises
import os.log

let logger = OSLog(subsystem: "io.livekit.example.screen-broadcaster",
                   category: "Broadcaster")

extension SampleHandler: RoomDelegate {
    //
}

class SampleHandler: RPBroadcastSampleHandler {

    var room: Room?
    var videoTrack: LocalVideoTrack?

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional.

        os_log("connecting to room...", log: logger, type: .debug)

        let options = ConnectOptions(
            // do not subscribe since this is for publish only
            autoSubscribe: false
        )

        LiveKit.connect("wss://rtc.unxpected.co.jp",
                        "",
                        options: options,
                        delegate: self).then { room in
            self.room = room
            os_log("connected to room", log: logger, type: .debug)
            do {
                let track = try LocalVideoTrack.createReplayKitTrack(name: "screen")
                self.videoTrack = track

                room.localParticipant?.publishVideoTrack(track: track).then({ _ in
                    os_log("did publish video track", log: logger, type: .debug)
                })
            } catch _ {
                os_log("failed to publish local track", log: logger, type: .error)
            }
        }
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

        guard let room = room else {
            return
        }

        room.disconnect()
    }

    //    override func finishBroadcastWithError(_ error: Error) {
    //        //
    //    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {

        // logger.debug("processSampleBuffer \(sampleBuffer.totalSampleSize, format: .byteCount) \(sampleBufferType.rawValue, format:.decimal())")

        os_log("process sample buffer", log: logger, type: .debug)

        switch sampleBufferType {
        case RPSampleBufferType.video:
            if let capturer = videoTrack?.capturer as? ReplayKitCapturer {
                capturer.encodeSampleBuffer(sampleBuffer)
            }
        default: break
        }
    }
}
