import Foundation
import SwiftUI
import LiveKit

struct PublishOptionsView: View {

    typealias OnPublish = (_ publishOptions: VideoPublishOptions) -> Void

    @State private var preferredVideoCodec: VideoCodec
    @State private var preferredBackupVideoCodec: VideoCodec

    private let providedPublishOptions: VideoPublishOptions
    private let onPublish: OnPublish

    init(publishOptions: VideoPublishOptions, _ onPublish: @escaping OnPublish) {
        self.providedPublishOptions = publishOptions
        self.onPublish = onPublish

        self.preferredVideoCodec = publishOptions.preferredCodec
        self.preferredBackupVideoCodec = publishOptions.preferredBackupCodec
    }

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Text("Publish options")
                .fontWeight(.bold)

            Picker("Codec", selection: $preferredVideoCodec) {
                ForEach(VideoCodec.allCases, id: \.self) {
                    Text($0.rawStringValue?.uppercased() ?? "Auto")
                }
            }

            Picker("Backup Codec", selection: $preferredBackupVideoCodec) {
                ForEach(VideoCodec.allCases.filter({ $0 != .av1 }), id: \.self) {
                    Text($0.rawStringValue?.uppercased() ?? "Auto")
                }
            }

            Button("Publish") {

                let result = VideoPublishOptions(
                    name: providedPublishOptions.name,
                    encoding: providedPublishOptions.encoding,
                    screenShareEncoding: providedPublishOptions.screenShareEncoding,
                    simulcast: providedPublishOptions.simulcast,
                    simulcastLayers: providedPublishOptions.simulcastLayers,
                    screenShareSimulcastLayers: providedPublishOptions.screenShareSimulcastLayers,
                    preferredCodec: preferredVideoCodec,
                    preferredBackupCodec: preferredBackupVideoCodec,
                    backupEncoding: providedPublishOptions.backupEncoding
                )

                onPublish(result)
            }
            .keyboardShortcut(.defaultAction)
        }
    }
}
