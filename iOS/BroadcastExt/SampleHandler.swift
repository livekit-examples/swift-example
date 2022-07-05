import ReplayKit
import LiveKit
import WebRTC
import Promises
import os.log

let logger = OSLog(subsystem: "io.livekit.example.screen-broadcaster",
                   category: "Broadcaster")

class SampleHandler: RPBroadcastSampleHandler {

    let room = Room()
    var bufferTrack: LocalVideoTrack?
    var audioTrack: LocalAudioTrack?

    var videoPublication: LocalTrackPublication?
    var audioPublication: LocalTrackPublication?

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {

        os_log("[LiveKitBroadcastExt] broadcast started", log: logger, type: .debug)

        Room.bypassVoiceProcessing = true

        let shared = RTCAudioSession.sharedInstance()
        shared.useManualAudio = true
        shared.isAudioEnabled = false

        guard let ud = UserDefaults(suiteName: "group.io.livekit.example.SwiftSDK.1"),
              let url = ud.string(forKey: "url"),
              let token = ud.string(forKey: "token") else {
            os_log("[LiveKitBroadcastExt] url & token unknown", log: logger, type: .debug)
            return
        }

        let connectOptions = ConnectOptions(
            // do not subscribe since this is for publish only
            autoSubscribe: false,
            publishOnlyMode: "screen_share"
        )

        let roomOptions = RoomOptions(
            defaultVideoPublishOptions: VideoPublishOptions(
                // simulcast: false
                screenShareSimulcastLayers: [
                    VideoParameters.presetScreenShareH720FPS15,
                    VideoParameters.presetScreenShareH1080FPS15,
                    VideoParameters.presetScreenShareH1080FPS30
                ]
            )
        )

        os_log("[LiveKitBroadcastExt] connecting with %@, %@", log: logger, type: .debug, url as NSString, token as NSString)

        room.connect(url,
                     token,
                     connectOptions: connectOptions,
                     roomOptions: roomOptions).then { (room) -> Promise<[LocalTrackPublication]> in

                        os_log("[LiveKitBroadcastExt] connect success", log: logger, type: .debug)

                        self.bufferTrack = LocalVideoTrack.createBufferTrack()
                        self.audioTrack = LocalAudioTrack.createTrack()
                        return all([
                            room.localParticipant!.publishVideoTrack(track: self.bufferTrack!),
                            room.localParticipant!.publishAudioTrack(track: self.audioTrack!,
                                                                     publishOptions: AudioPublishOptions(name: "app_audio",
                                                                                                         bitrate: 320 * 1024,
                                                                                                         dtx: false))
                        ])
                     }.then { publications in

                        self.videoPublication = publications[0]
                        self.audioPublication = publications[1]

                     }.catch { error in
                        os_log("[LiveKitBroadcastExt] connect error: %@", log: logger, type: .debug, error.localizedDescription as NSString)
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
                os_log("[LiveKitBroadcastExt] buffer track is nil", log: logger, type: .debug)
                return
            }

            capturer.capture(sampleBuffer)
            os_log("[LiveKitBroadcastExt] did capture video buffer", log: logger, type: .debug)

        case RPSampleBufferType.audioApp:
            let adm = Room.audioDeviceModule
            adm.mix(sampleBuffer)
            os_log("[LiveKitBroadcastExt] did capture audio buffer", log: logger, type: .debug)

        default: break
        }
    }
}
