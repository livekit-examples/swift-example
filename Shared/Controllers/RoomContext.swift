import SwiftUI
import LiveKit
import WebRTC
import Promises
import AVKit

// This class contains the logic to control behavior of the whole app.
final class RoomContext: NSObject, ObservableObject {

    private let store: ValueStore<Preferences>

    // Used to show connection error dialog
    // private var didClose: Bool = false
    @Published var shouldShowError: Bool = false
    public var latestError: Error?

    public let room = ExampleObservableRoom()

    @Published var url: String = "" {
        didSet { store.value.url = url }
    }

    @Published var token: String = "" {
        didSet { store.value.token = token }
    }

    // RoomOptions
    @Published var simulcast: Bool = true {
        didSet { store.value.simulcast = simulcast }
    }

    @Published var adaptiveStream: Bool = false {
        didSet { store.value.adaptiveStream = adaptiveStream }
    }

    @Published var dynacast: Bool = false {
        didSet { store.value.dynacast = dynacast }
    }

    @Published var reportStats: Bool = false {
        didSet { store.value.reportStats = reportStats }
    }

    // ConnectOptions
    @Published var autoSubscribe: Bool = true {
        didSet { store.value.autoSubscribe = autoSubscribe}
    }

    @Published var publish: Bool = false {
        didSet { store.value.publishMode = publish }
    }

    private let pipLayer = AVSampleBufferDisplayLayer()

    private lazy var pipCtrl: AVPictureInPictureController? = {
        //
        if #available(macOS 12.0, iOS 15.0, *) {
            try? AVAudioSession.sharedInstance().setActive(true)
            let r = AVPictureInPictureController(contentSource: .init(sampleBufferDisplayLayer: pipLayer, playbackDelegate: self))
            r.delegate = self
            r.canStartPictureInPictureAutomaticallyFromInline = true
            //            r.contentSource.

            return r
        }

        return nil
    }()

    public init(store: ValueStore<Preferences>) {
        self.store = store
        super.init()

        room.room.add(delegate: self)

        store.onLoaded.then { preferences in
            self.url = preferences.url
            self.token = preferences.token
            self.simulcast = preferences.simulcast
            self.adaptiveStream = preferences.adaptiveStream
            self.dynacast = preferences.dynacast
            self.reportStats = preferences.reportStats
            self.autoSubscribe = preferences.autoSubscribe
            self.publish = preferences.publishMode
        }

        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = true
        #endif

        print("PIP isPictureInPictureSupported: \(AVPictureInPictureController.isPictureInPictureSupported())")

        if let ctrl = pipCtrl {
            ctrl.startPictureInPicture()
            print("PIP did start pip")
        }
    }

    deinit {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = false
        #endif
        print("RoomContext.deinit")
    }

    func connect(entry: ConnectionHistory? = nil) -> Promise<Room> {

        if let entry = entry {
            url = entry.url
            token = entry.token
        }

        let connectOptions = ConnectOptions(
            autoSubscribe: !publish && autoSubscribe, // don't autosubscribe if publish mode
            publishOnlyMode: publish ? "publish_\(UUID().uuidString)" : nil
        )

        let roomOptions = RoomOptions(
            defaultCameraCaptureOptions: CameraCaptureOptions(
                dimensions: .h1080_169
            ),
            defaultScreenShareCaptureOptions: ScreenShareCaptureOptions(
                dimensions: .h1080_169,
                useBroadcastExtension: true
            ),
            defaultVideoPublishOptions: VideoPublishOptions(
                simulcast: publish ? false : simulcast
            ),
            adaptiveStream: adaptiveStream,
            dynacast: dynacast,
            reportStats: reportStats
        )

        return room.room.connect(url,
                                 token,
                                 connectOptions: connectOptions,
                                 roomOptions: roomOptions)
    }

    func disconnect() {
        room.room.disconnect()
    }
}

extension RoomContext: RoomDelegate {

    func room(_ room: Room, didUpdate connectionState: ConnectionState, oldValue: ConnectionState) {

        print("Did update connectionState \(connectionState) \(room.connectionState)")

        if let error = connectionState.disconnectedWithError {
            latestError = error
            DispatchQueue.main.async {
                self.shouldShowError = true
            }
        }

        DispatchQueue.main.async {
            withAnimation {
                self.objectWillChange.send()
            }
        }
    }

    //    func room(_ room: Room, localParticipant: LocalParticipant, didPublish publication: LocalTrackPublication) {
    //        //
    //    }
    //
    //    func room(_ room: Room, localParticipant: LocalParticipant, didUnpublish publication: LocalTrackPublication) {
    //        //
    //    }

    func room(_ room: Room, participant: RemoteParticipant, didSubscribe publication: RemoteTrackPublication, track: Track) {
        print("PIP did subscribe \(track)")
        guard let track = track as? VideoTrack else { return }
        track.add(videoRenderer: self)
        print("PIP did add renderer")
    }

    func room(_ room: Room, participant: RemoteParticipant, didUnsubscribe publication: RemoteTrackPublication, track: Track) {
        print("PIP did unpublish \(track)")
        guard let track = track as? VideoTrack else { return }
        track.remove(videoRenderer: self)
        print("PIP did remove renderer")
    }
}

extension RoomContext: VideoRenderer {

    func setSize(_ size: CGSize) {
        //

    }

    func renderFrame(_ frame: RTCVideoFrame?) {
        //
        guard let rtcPixelBuffer = frame?.buffer as? RTCCVPixelBuffer else {
            print("PIP RTCCVPixelBuffer is nil")
            return
        }

        guard let sampleBuffer = CMSampleBuffer.from(rtcPixelBuffer.pixelBuffer) else {
            print("PIP failed to create CMSampleBuffer")
            return
        }

        pipLayer.enqueue(sampleBuffer)

        guard let pipCtrl = pipCtrl else {
            print("PIP pipCtrl is nil")
            return
        }

        DispatchQueue.main.async {

            self.pipLayer.frame = CGRect(origin: .zero, size: .init(width: 100, height: 100))
            self.pipLayer.videoGravity = .resizeAspectFill

            print("PIP did enqueue active: \(pipCtrl.isPictureInPictureActive)")
            if !pipCtrl.isPictureInPictureActive {
                pipCtrl.startPictureInPicture()
            }
        }
    }
}

extension RoomContext: AVPictureInPictureControllerDelegate {

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        //
        print("PIP failedToStartPictureInPictureWithError: \(error)")
    }
}

extension RoomContext: AVPictureInPictureSampleBufferPlaybackDelegate {

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        //
    }

    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .negativeInfinity,
                    duration: .positiveInfinity)
    }

    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        false
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        //
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

func CopyVideoFrameToPixelBuffer(frameBuffer: RTCI420Buffer) -> CVPixelBuffer {

    var pixelBuffer: CVPixelBuffer!

    let result = CVPixelBufferCreate(kCFAllocatorDefault,
                                     Int(frameBuffer.width),
                                     Int(frameBuffer.height),
                                     kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                                     nil,
                                     &pixelBuffer)

    guard result == kCVReturnSuccess else { fatalError() }

    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

    //  RTC_DCHECK(pixelBuffer);
    //  RTC_DCHECK_EQ(CVPixelBufferGetPixelFormatType(pixelBuffer),
    //                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange);
    //  RTC_DCHECK_EQ(CVPixelBufferGetHeightOfPlane(pixelBuffer, 0),
    //                frameBuffer.height);
    //  RTC_DCHECK_EQ(CVPixelBufferGetWidthOfPlane(pixelBuffer, 0),
    //                frameBuffer.width);

    //    let cvRet: CVReturn = CVPixelBufferLockBaseAddress(pixelBuffer, [])
    //    if (cvRet != kCVReturnSuccess) { fatalError() }

    let dstY = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)

    let dstStrideY = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
    let dstUV = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)

    let dstStrideUV = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)

    // Convert I420 to NV12.
    //  int ret = libyuv::I420ToNV12(
    //      frameBuffer.dataY, frameBuffer.strideY, frameBuffer.dataU,
    //      frameBuffer.strideU, frameBuffer.dataV, frameBuffer.strideV, dstY,
    //      dstStrideY, dstUV, dstStrideUV, frameBuffer.width, frameBuffer.height);

    RTCYUVHelper.i420(toNV12: frameBuffer.dataY,
                      srcStrideY: frameBuffer.strideY,
                      srcU: frameBuffer.dataU,
                      srcStrideU: frameBuffer.strideU,
                      srcV: frameBuffer.dataV,
                      srcStrideV: frameBuffer.strideV,
                      dstY: dstY,
                      dstStrideY: Int32(dstStrideY),
                      dstUV: dstUV,
                      dstStrideUV: Int32(dstStrideUV),
                      width: frameBuffer.width,
                      width: frameBuffer.height)

    // CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

    //  if (ret) {
    //    RTC_LOG(LS_ERROR) << "Error converting I420 VideoFrame to NV12 :" << ret;
    //    return false;
    //  }

    return pixelBuffer
}
