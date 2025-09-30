/*
 * Copyright 2025 LiveKit
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

@preconcurrency import AVFoundation
import LiveKit
import SwiftUI

extension AVCaptureDevice: Swift.Identifiable {
    public var id: String { uniqueID }
}

struct PublishOptionsView: View {
    typealias OnPublish = (_ captureOptions: CameraCaptureOptions, _ publishOptions: VideoPublishOptions) -> Void

    @State private var devices: [AVCaptureDevice] = []
    @State private var device: AVCaptureDevice?
    @State private var simulcast: Bool
    @State private var preferredVideoCodec: VideoCodec?
    @State private var preferredBackupVideoCodec: VideoCodec?
    @State private var maxFPS: Int = 30

    @State private var presetDimensions: Dimensions? = .h1080_169
    @State private var customWidth: String = "1920"
    @State private var customHeight: String = "1080"

    private let providedPublishOptions: VideoPublishOptions
    private let onPublish: OnPublish

    init(publishOptions: VideoPublishOptions, _ onPublish: @escaping OnPublish) {
        providedPublishOptions = publishOptions
        self.onPublish = onPublish

        simulcast = publishOptions.simulcast
        preferredVideoCodec = publishOptions.preferredCodec
        preferredBackupVideoCodec = publishOptions.preferredBackupCodec
    }

    #if targetEnvironment(macCatalyst)
    typealias Container = VStack
    #else
    typealias Container = Form
    #endif

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Text("Publish options")
                .fontWeight(.bold)
            Container {
                Picker("Device", selection: $device) {
                    Text("Auto").tag(nil as AVCaptureDevice?)
                    ForEach(devices) {
                        Text($0.localizedName).tag($0 as AVCaptureDevice?)
                    }
                }

                Picker("Codec", selection: $preferredVideoCodec) {
                    Text("Auto").tag(nil as VideoCodec?)
                    ForEach(VideoCodec.all) {
                        Text($0.id.uppercased()).tag($0 as VideoCodec?)
                    }
                }.onChange(of: preferredVideoCodec) { newValue in
                    if newValue?.isSVC ?? false {
                        preferredBackupVideoCodec = .vp8
                    } else {
                        preferredBackupVideoCodec = nil
                    }
                }

                Picker("Backup Codec", selection: $preferredBackupVideoCodec) {
                    Text("Off").tag(nil as VideoCodec?)
                    ForEach(VideoCodec.allBackup.filter { $0 != preferredVideoCodec }) {
                        Text($0.id.uppercased()).tag($0 as VideoCodec?)
                    }
                }.disabled(!(preferredVideoCodec?.isSVC ?? false))

                Picker("Max FPS", selection: $maxFPS) {
                    ForEach(1 ... 30, id: \.self) {
                        Text("\($0)").tag($0)
                    }
                }

                Picker("Dimensions", selection: $presetDimensions) {
                    let items: [Dimensions?] = [Dimensions.h2160_169,
                                                Dimensions.h1440_169,
                                                Dimensions.h1080_169,
                                                Dimensions.h720_169,
                                                Dimensions.h540_169,
                                                Dimensions.h360_169,
                                                Dimensions.h216_169,
                                                Dimensions.h180_169,
                                                Dimensions.h90_169,
                                                nil]
                    ForEach(items, id: \.self) {
                        if let dimensions = $0 {
                            Text("\(dimensions.width)x\(dimensions.height)").tag(dimensions)
                        } else {
                            Text("Custom").tag(nil as Dimensions?)
                        }
                    }
                }

                if presetDimensions == nil {
                    TextField("Width", text: Binding(
                        get: { customWidth },
                        set: { customWidth = $0.filter { "0123456789".contains($0) }}
                    ))
                    #if !os(tvOS)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    #endif
                    TextField("Height", text: Binding(
                        get: { customHeight },
                        set: { customHeight = $0.filter { "0123456789".contains($0) }}
                    ))
                    #if !os(tvOS)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    #endif
                }

                Toggle("Simulcast", isOn: $simulcast)
            }

            Button("Publish") {
                let captureOptions = CameraCaptureOptions(
                    device: device,
                    dimensions: presetDimensions ?? Dimensions(width: Int32(customWidth) ?? 1920,
                                                               height: Int32(customHeight) ?? 1080)
                )

                let publishOptions = VideoPublishOptions(
                    name: providedPublishOptions.name,
                    encoding: VideoEncoding(maxBitrate: VideoParameters.presetH1080_169.encoding.maxBitrate, maxFps: maxFPS),
                    screenShareEncoding: providedPublishOptions.screenShareEncoding,
                    simulcast: simulcast,
                    simulcastLayers: providedPublishOptions.simulcastLayers,
                    screenShareSimulcastLayers: providedPublishOptions.screenShareSimulcastLayers,
                    preferredCodec: preferredVideoCodec,
                    preferredBackupCodec: preferredBackupVideoCodec
                )

                onPublish(captureOptions, publishOptions)
            }
            #if !os(tvOS)
            .keyboardShortcut(.defaultAction)
            #endif

            Spacer()
        }
        .onAppear(perform: {
            Task {
                devices = try await CameraCapturer.captureDevices()
                #if !os(macOS)
                    .singleDeviceforEachPosition()
                #endif
            }
        })
    }
}
