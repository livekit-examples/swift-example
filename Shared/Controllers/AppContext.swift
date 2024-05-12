/*
 * Copyright 2024 LiveKit
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Combine
import LiveKit
import Photos
import ReplayKit
import SwiftUI

// This class contains the logic to control behavior of the whole app.
final class AppContext: ObservableObject {
    private let store: ValueStore<Preferences>

    @Published var videoViewVisible: Bool = true {
        didSet { store.value.videoViewVisible = videoViewVisible }
    }

    @Published var showInformationOverlay: Bool = false {
        didSet { store.value.showInformationOverlay = showInformationOverlay }
    }

    @Published var preferSampleBufferRendering: Bool = false {
        didSet { store.value.preferSampleBufferRendering = preferSampleBufferRendering }
    }

    @Published var videoViewMode: VideoView.LayoutMode = .fit {
        didSet { store.value.videoViewMode = videoViewMode }
    }

    @Published var videoViewMirrored: Bool = false {
        didSet { store.value.videoViewMirrored = videoViewMirrored }
    }

    @Published var connectionHistory: Set<ConnectionHistory> = [] {
        didSet { store.value.connectionHistory = connectionHistory }
    }

    @Published var outputDevice: AudioDevice = AudioManager.shared.defaultOutputDevice {
        didSet {
            print("didSet outputDevice: \(String(describing: outputDevice))")
            AudioManager.shared.outputDevice = outputDevice
        }
    }

    @Published var inputDevice: AudioDevice = AudioManager.shared.defaultInputDevice {
        didSet {
            print("didSet inputDevice: \(String(describing: inputDevice))")
            AudioManager.shared.inputDevice = inputDevice
        }
    }

    @Published var preferSpeakerOutput: Bool = true {
        didSet { AudioManager.shared.isSpeakerOutputPreferred = preferSpeakerOutput }
    }

    var videoComposer: VideoComposer?

    @Published var isRecorderEnabled: Bool = false {
        didSet {
            let recorder = RPScreenRecorder.shared()
            if isRecorderEnabled {
                videoComposer = VideoComposer()
                try? videoComposer?.setupAssetWriter()
                recorder.isMicrophoneEnabled = true
                recorder.startCapture { buffer, bufferType, error in
                    //
                    if let error {
                        print("RPScreenRecorder error: \(error)")
                        return
                    }

                    print("RPScreenRecorder buffer type: \(bufferType)")

                    if bufferType == .video {
                        if let imageBuffer = CMSampleBufferGetImageBuffer(buffer) {
                            let w = CVPixelBufferGetWidth(imageBuffer)
                            let h = CVPixelBufferGetHeight(imageBuffer)
                            print("VideoBuffer dimensions \(w)x\(h)")
                        }
                    }

                    self.videoComposer?.processSampleBuffer(buffer, ofType: bufferType)
                }
            } else {
                recorder.stopCapture()
                videoComposer?.finishWriting {
                    //
                }
                // videoComposer = nil
            }
        }
    }

    public init(store: ValueStore<Preferences>) {
        self.store = store

        videoViewVisible = store.value.videoViewVisible
        showInformationOverlay = store.value.showInformationOverlay
        preferSampleBufferRendering = store.value.preferSampleBufferRendering
        videoViewMode = store.value.videoViewMode
        videoViewMirrored = store.value.videoViewMirrored
        connectionHistory = store.value.connectionHistory

        AudioManager.shared.onDeviceUpdate = { [weak self] audioManager in
            guard let self else { return }
            print("devices did update")
            // force UI update for outputDevice / inputDevice
            Task.detached { @MainActor [weak self] in
                guard let self else { return }
                self.outputDevice = audioManager.outputDevice
                self.inputDevice = audioManager.inputDevice
            }
        }
    }
}

class VideoComposer {
    var assetWriter: AVAssetWriter?
    var videoInput: AVAssetWriterInput?
    var audioInput: AVAssetWriterInput?

    func setupAssetWriter() throws {
        let dir = FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)

        let outputURL = dir.appendingPathComponent(UUID().uuidString + ".mp4")
        print("outputURL: \(outputURL)")

        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        // Setup video input
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 886,
            AVVideoHeightKey: 1920,
        ]

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true
        if let videoInput, assetWriter?.canAdd(videoInput) ?? false {
            assetWriter?.add(videoInput)
        } else {
            fatalError()
        }

        // Setup audio input
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 48 * 1000,
            AVEncoderBitRateKey: 128_000,
        ]
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput?.expectsMediaDataInRealTime = true
        if let audioInput, assetWriter?.canAdd(audioInput) ?? false {
            assetWriter?.add(audioInput)
        } else {
            fatalError()
        }
    }

    func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, ofType type: RPSampleBufferType) {
        guard let assetWriter else { return }

        if assetWriter.status == .unknown {
            if assetWriter.startWriting() {
                assetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            }
        }

        if assetWriter.status == .writing {
            if type == .video, videoInput?.isReadyForMoreMediaData == true {
                videoInput?.append(sampleBuffer)
            } else if type == .audioMic, audioInput?.isReadyForMoreMediaData == true {
                audioInput?.append(sampleBuffer)
            }
        }
    }

    func finishWriting(completion: @escaping () -> Void) {
        assetWriter?.finishWriting { [weak self] in
            guard let outputURL = self?.assetWriter?.outputURL else { return }
            print("outputURL: \(outputURL)")

            if self?.assetWriter?.status == .failed {
                print("Failed to finish writing \(String(describing: self?.assetWriter?.error)) : \(self?.assetWriter?.error?.localizedDescription ?? "Unknown error")")
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
            } completionHandler: { success, error in
                if success {
                    print("Video saved to Photos")
                } else {
                    print("Error saving video: \(String(describing: error))")
                }
                completion()
            }
        }
    }
}
