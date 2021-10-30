import SwiftUI
import LiveKit

struct ParticipantView: View {

    @ObservedObject var participant: ObservableParticipant

    var body: some View {
        GeometryReader { geometry in

            ZStack(alignment: .bottom) {
                // Background color
                Color.lkDarkBlue
                    .ignoresSafeArea()

                // VideoView for the Participant
                if let track = participant.firstVideoTrack {
                    SwiftUIVideoView(track: track)
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
            // Glow the border when the participant is speaking
            .border(Color.blue.opacity(0.5),
                    width: participant.isSpeaking ? 5.0 : 0.0)
        }
    }
}
