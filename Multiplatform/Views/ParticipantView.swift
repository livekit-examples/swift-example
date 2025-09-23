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

import LiveKit
import LiveKitComponents
import SFSafeSymbols
import SwiftUI

struct ParticipantView: View {
    @ObservedObject var participant: Participant
    @EnvironmentObject var appCtx: AppContext

    var videoViewMode: VideoView.LayoutMode = .fill
    var onTap: ((_ participant: Participant) -> Void)?

    @State private var isRendering: Bool = false

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
                   !publication.isMuted,
                   let track = publication.track as? VideoTrack,
                   appCtx.videoViewVisible
                {
                    ZStack(alignment: .topLeading) {
                        SwiftUIVideoView(track,
                                         layoutMode: videoViewMode,
                                         mirrorMode: appCtx.videoViewMirrored ? .mirror : .auto,
                                         renderMode: appCtx.preferSampleBufferRendering ? .sampleBuffer : .auto,
                                         pinchToZoomOptions: appCtx.videoViewPinchToZoomOptions,
                                         isDebugMode: appCtx.showInformationOverlay,
                                         isRendering: $isRendering)

                        if !isRendering {
                            ProgressView().progressViewStyle(CircularProgressViewStyle())
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                    }
                } else if let publication = participant.mainVideoPublication as? RemoteTrackPublication,
                          case .notAllowed = publication.subscriptionState
                {
                    // Show no permission icon
                    bgView(systemSymbol: .exclamationmarkCircle, geometry: geometry)
                } else if let publication = participant.firstAudioPublication, !publication.isMuted, let track = publication.track as? AudioTrack {
                    BarAudioVisualizer(audioTrack: track)
                } else {
                    // Show no camera icon
                    bgView(systemSymbol: .videoSlashFill, geometry: geometry)
                }

                if appCtx.showInformationOverlay {
                    VStack(alignment: .leading, spacing: 5) {
                        // Video stats
                        if let publication = participant.mainVideoPublication,
                           !publication.isMuted,
                           let track = publication.track as? VideoTrack
                        {
                            StatsView(track: track)
                        }
                        // Audio stats
                        if let publication = participant.firstAudioPublication,
                           !publication.isMuted,
                           let track = publication.track as? AudioTrack
                        {
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
                                         mirrorMode: appCtx.videoViewMirrored ? .mirror : .auto)
                            .background(Color.black)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: min(geometry.size.width, geometry.size.height) * 0.3)
                            .cornerRadius(8)
                            .padding()
                    }

                    // Bottom user info bar
                    HStack {
                        if let identity = participant.identity {
                            Text(String(describing: identity))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }

                        if let publication = participant.mainVideoPublication,
                           !publication.isMuted
                        {
                            // is remote
                            if let remotePub = publication as? RemoteTrackPublication {
                                Menu {
                                    if case .subscribed = remotePub.subscriptionState {
                                        Button("Unsubscribe") {
                                            Task { try await remotePub.set(subscribed: false) }
                                        }
                                    } else if case .unsubscribed = remotePub.subscriptionState {
                                        Button("Subscribe") {
                                            Task { try await remotePub.set(subscribed: true) }
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
                                .menuIndicator(.visible)
                                .menuStyle(BorderlessButtonMenuStyle())
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
                           !publication.isMuted
                        {
                            // is remote
                            if let remotePub = publication as? RemoteTrackPublication {
                                Menu {
                                    if case .subscribed = remotePub.subscriptionState {
                                        Button("Unsubscribe") {
                                            Task { try await remotePub.set(subscribed: false) }
                                        }
                                    } else if case .unsubscribed = remotePub.subscriptionState {
                                        Button("Subscribe") {
                                            Task { try await remotePub.set(subscribed: true) }
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
                                .menuIndicator(.visible)
                                .menuStyle(BorderlessButtonMenuStyle())
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
    private let track: Track
    @ObservedObject private var observer: TrackDelegateObserver

    init(track: Track) {
        self.track = track
        observer = TrackDelegateObserver(track: track)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            VStack(alignment: .leading, spacing: 5) {
                if track is VideoTrack {
                    HStack(spacing: 3) {
                        Image(systemSymbol: .videoFill)
                        Text("Video").fontWeight(.bold)
                        if let dimensions = observer.dimensions {
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

                // if let trackStats = viewModel.statistics {
                ForEach(observer.allStatisticts, id: \.self) { trackStats in
                    ForEach(trackStats.outboundRtpStream.sortedByRidIndex()) { stream in
                        HStack(spacing: 3) {
                            Image(systemSymbol: .arrowUp)

                            if let codec = trackStats.codec.first(where: { $0.id == stream.codecId }) {
                                Text(codec.mimeType ?? "?")
                            }

                            if let rid = stream.rid, !rid.isEmpty {
                                Text(rid.uppercased())
                            }

                            Text(stream.formattedBps())

                            if let reason = stream.qualityLimitationReason, reason != QualityLimitationReason.none {
                                Image(systemSymbol: .exclamationmarkTriangleFill)
                                Text(reason.rawValue.capitalized)
                            }
                        }
                    }
                    ForEach(trackStats.inboundRtpStream) { stream in
                        HStack(spacing: 3) {
                            Image(systemSymbol: .arrowDown)

                            if let codec = trackStats.codec.first(where: { $0.id == stream.codecId }) {
                                Text(codec.mimeType ?? "?")
                            }

                            Text(stream.formattedBps())
                        }
                    }
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
