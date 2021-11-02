import SwiftUI
import LiveKit

struct ParticipantView: View {

    @ObservedObject var participant: ObservableParticipant
    var videoViewMode: VideoView.Mode = .fill

    var body: some View {
        GeometryReader { geometry in

            ZStack(alignment: .bottom) {
                // Background color
                Color.lkDarkBlue
                    .ignoresSafeArea()

                // VideoView for the Participant
                if let track = participant.firstVideoTrack {
                    SwiftUIVideoView(track: track, mode: videoViewMode)
                        .background(Color.black)
                } else {
                    // Show no camera icon
                    Image(systemName: "video.slash.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(Color.lkBlue.opacity(0.7))
                        .frame(width: geometry.size.width * 0.3)
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity
                        )
                }

                HStack {
                    Text(participant.identity ?? "-")
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if participant.firstAudioAvailable {
                        Image(systemName: "mic.fill")
                    } else {
                        Image(systemName: "mic.slash.fill")
                            .foregroundColor(Color.red)
                    }
                }.padding(5)
                .frame(minWidth: 0,
                       maxWidth: .infinity)
                .background(Color.black.opacity(0.5))
            }
            .cornerRadius(8)
            // Glow the border when the participant is speaking
            .overlay(
                participant.isSpeaking ?
                    RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue, lineWidth: 5.0)
                    : nil
            )
        }
    }
}
