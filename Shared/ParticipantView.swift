import SwiftUI
import LiveKit
import SFSafeSymbols

struct ParticipantView: View {

    @ObservedObject var participant: Participant
    @EnvironmentObject var appCtx: AppContext

    var videoViewMode: VideoView.LayoutMode = .fill
    var onTap: ((_ participant: Participant) -> Void)?

    @State private var isRendering: Bool = false
    @State private var dimensions: Dimensions?
    @State private var videoTrackStats: TrackStatistics?

    func bgView(systemSymbol: SFSymbol, geometry: GeometryProxy) -> some View {
        Image(systemSymbol: systemSymbol)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(Color.lkGray2)
            .frame(width: min(geometry.size.width, geometry.size.height) * 0.3)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
    }

    var body: some View {
        GeometryReader { geometry in

            ZStack(alignment: .bottom) {
                // Background color
                Color.lkGray1
                    .ignoresSafeArea()

                // VideoView for the Participant
                if let publication = participant.mainVideoPublication,
                   !publication.muted,
                   let track = publication.track as? VideoTrack,
                   appCtx.videoViewVisible {
                    ZStack(alignment: .topLeading) {
                        SwiftUIVideoView(track,
                                         layoutMode: videoViewMode,
                                         mirrorMode: appCtx.videoViewMirrored ? .mirror : .auto,
                                         renderMode: appCtx.preferSampleBufferRendering ? .sampleBuffer : .auto,
                                         debugMode: appCtx.showInformationOverlay,
                                         isRendering: $isRendering,
                                         dimensions: $dimensions,
                                         trackStatistics: $videoTrackStats)

                        if !isRendering {
                            ProgressView().progressViewStyle(CircularProgressViewStyle())
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                    }
                } else if let publication = participant.mainVideoPublication as? RemoteTrackPublication,
                          case .notAllowed = publication.subscriptionState {
                    // Show no permission icon
                    bgView(systemSymbol: .exclamationmarkCircle, geometry: geometry)
                } else {
                    // Show no camera icon
                    bgView(systemSymbol: .videoSlashFill, geometry: geometry)
                }

                if appCtx.showInformationOverlay {

                    VStack(alignment: .leading, spacing: 5) {
                        // Video stats
                        if let publication = participant.mainVideoPublication,
                           !publication.muted,
                           let track = publication.track as? VideoTrack {
                            StatsView(track: track)
                        }
                        // Audio stats
                        if let publication = participant.firstAudioPublication,
                           !publication.muted,
                           let track = publication.track as? AudioTrack {
                            StatsView(track: track)
                        }
                    }
                    .padding(8)
                    .frame(
                        minWidth: 0,
                        maxWidth: .infinity,
                        minHeight: 0,
                        maxHeight: .infinity,
                        alignment: .topLeading
                    )

                }

                VStack(alignment: .trailing, spacing: 0) {
                    // Show the sub-video view
                    if let subVideoTrack = participant.subVideoTrack {
                        SwiftUIVideoView(subVideoTrack,
                                         layoutMode: .fill,
                                         mirrorMode: appCtx.videoViewMirrored ? .mirror : .auto
                        )
                        .background(Color.black)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: min(geometry.size.width, geometry.size.height) * 0.3)
                        .cornerRadius(8)
                        .padding()
                    }

                    // Bottom user info bar
                    HStack {
                        Text("\(participant.identity)") //  (\(participant.publish ?? "-"))
                            .lineLimit(1)
                            .truncationMode(.tail)

                        if let publication = participant.mainVideoPublication,
                           !publication.muted {

                            // is remote
                            if let remotePub = publication as? RemoteTrackPublication {
                                Menu {
                                    if case .subscribed = remotePub.subscriptionState {
                                        Button {
                                            remotePub.set(subscribed: false)
                                        } label: {
                                            Text("Unsubscribe")
                                        }
                                    } else if case .unsubscribed = remotePub.subscriptionState {
                                        Button {
                                            remotePub.set(subscribed: true)
                                        } label: {
                                            Text("Subscribe")
                                        }

                                    }
                                } label: {
                                    if case .subscribed = remotePub.subscriptionState {
                                        Image(systemSymbol: .videoFill)
                                            .foregroundColor(Color.green)
                                    } else if case .notAllowed = remotePub.subscriptionState {
                                        Image(systemSymbol: .exclamationmarkCircle)
                                            .foregroundColor(Color.red)
                                    } else {
                                        Image(systemSymbol: .videoSlashFill)
                                    }
                                }
                                #if os(macOS)
                                .menuStyle(BorderlessButtonMenuStyle(showsMenuIndicator: true))
                                #elseif os(iOS)
                                .menuStyle(BorderlessButtonMenuStyle())
                                #endif
                                .fixedSize()
                            } else {
                                // local
                                Image(systemSymbol: .videoFill)
                                    .foregroundColor(Color.green)
                            }

                        } else {
                            Image(systemSymbol: .videoSlashFill)
                                .foregroundColor(Color.white)
                        }

                        if let publication = participant.firstAudioPublication,
                           !publication.muted {

                            // is remote
                            if let remotePub = publication as? RemoteTrackPublication {
                                Menu {
                                    if case .subscribed = remotePub.subscriptionState {
                                        Button {
                                            remotePub.set(subscribed: false)
                                        } label: {
                                            Text("Unsubscribe")
                                        }
                                    } else if case .unsubscribed = remotePub.subscriptionState {
                                        Button {
                                            remotePub.set(subscribed: true)
                                        } label: {
                                            Text("Subscribe")
                                        }

                                    }
                                } label: {
                                    if case .subscribed = remotePub.subscriptionState {
                                        Image(systemSymbol: .micFill)
                                            .foregroundColor(Color.orange)
                                    } else if case .notAllowed = remotePub.subscriptionState {
                                        Image(systemSymbol: .exclamationmarkCircle)
                                            .foregroundColor(Color.red)
                                    } else {
                                        Image(systemSymbol: .micSlashFill)
                                    }
                                }
                                #if os(macOS)
                                .menuStyle(BorderlessButtonMenuStyle(showsMenuIndicator: true))
                                #elseif os(iOS)
                                .menuStyle(BorderlessButtonMenuStyle())
                                #endif
                                .fixedSize()
                            } else {
                                // local
                                Image(systemSymbol: .micFill)
                                    .foregroundColor(Color.orange)
                            }

                        } else {
                            Image(systemSymbol: .micSlashFill)
                                .foregroundColor(Color.white)
                        }

                        if participant.connectionQuality == .excellent {
                            Image(systemSymbol: .wifi)
                                .foregroundColor(.green)
                        } else if participant.connectionQuality == .good {
                            Image(systemSymbol: .wifi)
                                .foregroundColor(Color.orange)
                        } else if participant.connectionQuality == .poor {
                            Image(systemSymbol: .wifiExclamationmark)
                                .foregroundColor(Color.red)
                        }

                        if participant.firstTrackEncryptionType == .none {
                            Image(systemSymbol: .lockOpenFill)
                                .foregroundColor(.red)
                        } else {
                            Image(systemSymbol: .lockFill)
                                .foregroundColor(.green)
                        }

                    }.padding(5)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .background(Color.black.opacity(0.5))
                }
            }
            .cornerRadius(8)
            // Glow the border when the participant is speaking
            .overlay(
                participant.isSpeaking ?
                    RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.blue, lineWidth: 5.0)
                    : nil
            )
        }.gesture(TapGesture()
                    .onEnded { _ in
                        // Pass the tap event
                        onTap?(participant)
                    })
    }
}

struct StatsView: View {

    @ObservedObject private var viewModel: DelegateObserver
    private let track: Track

    init(track: Track) {
        self.track = track
        viewModel = DelegateObserver(track: track)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            VStack(alignment: .leading, spacing: 5) {
                if track is VideoTrack {
                    HStack(spacing: 3) {
                        Image(systemSymbol: .videoFill)
                        Text("Video").fontWeight(.bold)
                        if let dimensions = viewModel.dimensions {
                            Text("\(dimensions.width)×\(dimensions.height)")
                        }
                    }
                } else if track is AudioTrack {
                    HStack(spacing: 3) {
                        Image(systemSymbol: .micFill)
                        Text("Audio").fontWeight(.bold)
                    }
                } else {
                    Text("Unknown").fontWeight(.bold)
                }

                if let trackStats = viewModel.statistics {

//                    if trackStats.bpsSent != 0 {
//                        HStack(spacing: 3) {
//                            if let codecName = trackStats.codecName {
//                                Text(codecName.uppercased()).fontWeight(.bold)
//                            }
//                            Image(systemSymbol: .arrowUpCircle)
//                            Text(trackStats.formattedBpsSent())
//                        }
//                    }
//
//                    if trackStats.bpsReceived != 0 {
//                        HStack(spacing: 3) {
//                            if let codecName = trackStats.codecName {
//                                Text(codecName.uppercased()).fontWeight(.bold)
//                            }
//                            Image(systemSymbol: .arrowDownCircle)
//                            Text(trackStats.formattedBpsReceived())
//                        }
//                    }
                }
            }
            .font(.system(size: 10))
            .foregroundColor(Color.white)
            .padding(5)
            .background(Color.black.opacity(0.5))
            .cornerRadius(8)
        }
    }
}

extension StatsView {

    class DelegateObserver: ObservableObject, TrackDelegate {
        private let track: Track
        @Published var dimensions: Dimensions?
        @Published var statistics: TrackStatistics?

        init(track: Track) {
            self.track = track

            dimensions = track.dimensions
            statistics = track.statistics

            track.add(delegate: self)
        }

        func track(_ track: VideoTrack, didUpdate dimensions: Dimensions?) {
            Task.detached { @MainActor in
                self.dimensions = dimensions
            }
        }

        func track(_ track: Track, didUpdateStatistics statistics: TrackStatistics) {
            Task.detached { @MainActor in
                self.statistics = statistics
            }
        }
    }
}
