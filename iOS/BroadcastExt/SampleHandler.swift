import ReplayKit
import LiveKit
import WebRTC
import Promises
import os.log

let logger = OSLog(subsystem: "io.livekit.example.screen-broadcaster",
                   category: "Broadcaster")

class SampleHandler: RPBroadcastSampleHandler {

    lazy var room = Room()
    var bufferTrack: LocalVideoTrack?
    var publication: LocalTrackPublication?

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {

        os_log("broadcast started", log: logger, type: .debug)

        if let ud = UserDefaults(suiteName: "group.livekit-example.broadcast"),
           let url = ud.string(forKey: "url"),
           let token = ud.string(forKey: "token") {

            let connectOptions = ConnectOptions(
                // do not subscribe since this is for publish only
                autoSubscribe: false,
                publishOnlyMode: "screen_share"
            )

            let roomOptions = RoomOptions(
                defaultVideoPublishOptions: VideoPublishOptions(
                    simulcast: false
                )
            )

            room.connect(url,
                         token,
                         connectOptions: connectOptions,
                         roomOptions: roomOptions).then { (room) -> Promise<LocalTrackPublication> in
                            self.bufferTrack = LocalVideoTrack.createBufferTrack()
                            return room.localParticipant!.publishVideoTrack(track: self.bufferTrack!)
                         }.then { publication in
                            self.publication = publication
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

        room.disconnect()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {

        // os_log("processSampleBuffer", log: logger, type: .debug)

        switch sampleBufferType {
        case RPSampleBufferType.video:

            guard let capturer = bufferTrack?.capturer as? BufferCapturer else {
                return
            }

            capturer.capture(sampleBuffer)

        default: break
        }
    }
}
