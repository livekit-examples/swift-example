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

import Foundation
import LiveKit
import SwiftUI

struct PublishOptionsView: View {
    typealias OnPublish = (_ publishOptions: VideoPublishOptions) -> Void

    @State private var simulcast: Bool = true
    @State private var preferredVideoCodec: VideoCodec?
    @State private var preferredBackupVideoCodec: VideoCodec?

    private let providedPublishOptions: VideoPublishOptions
    private let onPublish: OnPublish

    init(publishOptions: VideoPublishOptions, _ onPublish: @escaping OnPublish) {
        providedPublishOptions = publishOptions
        self.onPublish = onPublish

        simulcast = publishOptions.simulcast
        preferredVideoCodec = publishOptions.preferredCodec
        preferredBackupVideoCodec = publishOptions.preferredBackupCodec
    }

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Text("Publish options")
                .fontWeight(.bold)

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

            Toggle(isOn: $simulcast, label: {
                Text("Simulcast")
            })

            Button("Publish") {
                let result = VideoPublishOptions(
                    name: providedPublishOptions.name,
                    encoding: providedPublishOptions.encoding,
                    screenShareEncoding: providedPublishOptions.screenShareEncoding,
                    simulcast: simulcast,
                    simulcastLayers: providedPublishOptions.simulcastLayers,
                    screenShareSimulcastLayers: providedPublishOptions.screenShareSimulcastLayers,
                    preferredCodec: preferredVideoCodec,
                    preferredBackupCodec: preferredBackupVideoCodec
                )

                onPublish(result)
            }
            .keyboardShortcut(.defaultAction)
        }
    }
}
