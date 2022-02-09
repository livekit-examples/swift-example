import SwiftUI
import LiveKit
import SFSafeSymbols

struct ParticipantView: View {

    @ObservedObject var participant: ObservableParticipant
    @EnvironmentObject var appCtx: AppContext

    var videoViewMode: VideoView.Mode = .fill
    var onTap: ((_ participant: ObservableParticipant) -> Void)?

    @State private var dimensions: Dimensions?

    func bgView(systemSymbol: SFSymbol, geometry: GeometryProxy) -> some View {
        Image(systemSymbol: systemSymbol)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(Color.lkBlue.opacity(0.7))
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
                Color.lkDarkBlue
                    .ignoresSafeArea()

                // VideoView for the Participant
                if let publication = participant.mainVideoPublication,
                   !publication.muted,
                   let track = publication.track as? VideoTrack,
                   appCtx.videoViewVisible {
                    ZStack(alignment: .topLeading) {
                        SwiftUIVideoView(track,
                                         mode: videoViewMode,
                                         mirrored: true, dimensions: $dimensions,
                                         preferMetal: appCtx.preferMetal)
                            .background(Color.black)

                        // Show the actual video dimensions (if enabled)
                        if appCtx.showInformationOverlay {
                            VStack(alignment: .leading) {
                                if  let dimensions = dimensions {
                                    Text("DIM. \(dimensions.width)x\(dimensions.height)")
                                        .foregroundColor(Color.white)
                                        .padding(3)
                                        .background(Color.lkBlue)
                                        .cornerRadius(8)

                                }
                                Text("Metal: \(String(describing: appCtx.preferMetal))")
                                    .foregroundColor(Color.white)
                                    .padding(3)
                                    .background(Color.green)
                                    .cornerRadius(8)

                            }
                            .padding()
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

                VStack(alignment: .trailing, spacing: 0) {
                    // Show the sub-video view
                    if let subVideoTrack = participant.subVideoTrack {
                        SwiftUIVideoView(subVideoTrack, mode: .fill,
                                         preferMetal: appCtx.preferMetal)
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
                                        Image(systemName: SFSymbol.videoFill.rawValue)
                                            .foregroundColor(Color.green)
                                    } else if case .notAllowed = remotePub.subscriptionState {
                                        Image(systemName: SFSymbol.exclamationmarkCircle.rawValue)
                                            .foregroundColor(Color.red)
                                    } else {
                                        Image(systemName: SFSymbol.videoSlashFill.rawValue)
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
                                Image(systemName: SFSymbol.videoFill.rawValue)
                                    .foregroundColor(Color.green)
                            }

                        } else {
                            Image(systemName: SFSymbol.videoSlashFill.rawValue)
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
                                        Image(systemName: SFSymbol.micFill.rawValue)
                                            .foregroundColor(Color.orange)
                                    } else if case .notAllowed = remotePub.subscriptionState {
                                        Image(systemName: SFSymbol.exclamationmarkCircle.rawValue)
                                            .foregroundColor(Color.red)
                                    } else {
                                        Image(systemName: SFSymbol.micSlashFill.rawValue)
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
                                Image(systemName: SFSymbol.micFill.rawValue)
                                    .foregroundColor(Color.orange)
                            }

                        } else {
                            Image(systemName: SFSymbol.micSlashFill.rawValue)
                                .foregroundColor(Color.white)
                        }

                        if participant.connectionQuality == .excellent {
                            Image(systemName: SFSymbol.wifi.rawValue)
                                .foregroundColor(.green)
                        } else if participant.connectionQuality == .good {
                            Image(systemName: SFSymbol.wifi.rawValue)
                                .foregroundColor(Color.orange)
                        } else if participant.connectionQuality == .poor {
                            Image(systemName: SFSymbol.wifiExclamationmark.rawValue)
                                .foregroundColor(Color.red)
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
                    RoundedRectangle(cornerRadius: 8)
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
