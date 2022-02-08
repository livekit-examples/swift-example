import SwiftUI
import LiveKit
import SFSafeSymbols

struct ParticipantView: View {

    @ObservedObject var participant: ObservableParticipant
    @EnvironmentObject var appCtx: AppContext

    var videoViewMode: VideoView.Mode = .fill
    var onTap: ((_ participant: ObservableParticipant) -> Void)?

    @State private var dimensions: Dimensions?

    var body: some View {
        GeometryReader { geometry in

            ZStack(alignment: .bottom) {
                // Background color
                Color.lkDarkBlue
                    .ignoresSafeArea()

                // VideoView for the Participant
                if let track = participant.mainVideoTrack,
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
                } else {
                    // Show no camera icon
                    Image(systemName: "video.slash.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(Color.lkBlue.opacity(0.7))
                        .frame(width: min(geometry.size.width, geometry.size.height) * 0.3)
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity
                        )
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

                        if participant.firstAudioAvailable {
                            Image(systemName: "mic.fill")
                        } else {
                            Image(systemName: "mic.slash.fill")
                                .foregroundColor(Color.red)
                        }

                        if participant.connectionQuality == .excellent {
                            Image(systemName: "wifi")
                                .foregroundColor(.green)
                        } else if participant.connectionQuality == .good {
                            Image(systemName: "wifi")
                                .foregroundColor(Color.orange)
                        } else if participant.connectionQuality == .poor {
                            Image(systemName: "wifi.exclamationmark")
                                .foregroundColor(Color.red)
                        }

                        if let remoteParticipant = participant.asRemote {
                            if  remoteParticipant.audioTracks.first != nil {
                                Menu {
                                    Button {
                                        // roomCtx.room.room.sendSimulate(scenario: .nodeFailure)
                                    } label: {
                                        Text("Unsubscribe")
                                    }

                                    Button {
                                        // roomCtx.room.room.sendSimulate(scenario: .serverLeave)
                                    } label: {
                                        Text("Subscribe")
                                    }

                                } label: {
                                    Image(systemName: "speaker.wave.3.fill")
                                }
                                #if os(macOS)
                                .menuStyle(BorderlessButtonMenuStyle(showsMenuIndicator: true))
                                #elseif os(iOS)
                                .menuStyle(BorderlessButtonMenuStyle())
                                #endif
                                .fixedSize()
                            }
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
