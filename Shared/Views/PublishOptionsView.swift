import Foundation
import SwiftUI
import LiveKit

struct PublishOptionsView: View {

    typealias OnPublish = (_ publishOptions: VideoPublishOptions) -> Void

    @State private var preferredVideoCodec: PreferredVideoCodec

    private let providedPublishOptions: VideoPublishOptions
    private let onPublish: OnPublish

    init(publishOptions: VideoPublishOptions, _ onPublish: @escaping OnPublish) {
        self.providedPublishOptions = publishOptions
        self.onPublish = onPublish

        self.preferredVideoCodec = publishOptions.preferredCodec
    }

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Text("Publish options")
                .fontWeight(.bold)

            Picker("Codec", selection: $preferredVideoCodec) {
                ForEach(PreferredVideoCodec.allCases, id: \.self) {
                    Text($0.rawStringValue?.uppercased() ?? "Auto")
                }
            }

            LKButton(title: "Publish") {

                let result = VideoPublishOptions(
                    name: providedPublishOptions.name,
                    encoding: providedPublishOptions.encoding,
                    screenShareEncoding: providedPublishOptions.screenShareEncoding,
                    simulcast: providedPublishOptions.simulcast,
                    simulcastLayers: providedPublishOptions.simulcastLayers,
                    screenShareSimulcastLayers: providedPublishOptions.screenShareSimulcastLayers,
                    preferredCodec: preferredVideoCodec,
                    preferredBackupCodec: providedPublishOptions.preferredBackupCodec,
                    backupEncoding: providedPublishOptions.backupEncoding
                )

                onPublish(result)
            }
        }
    }
}
