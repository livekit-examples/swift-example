import SwiftUI
import LiveKit

final class RoomViewCtrl: ObservableObject, RoomDelegate {

    let id = UUID()
    let room = AppCtrl.shared.room

    var participants: [ObservableParticipant] = []

    init() {
        print("RoomViewCtrl init \(id)")

        room?.add(delegate: self)

        if let participants = room?.remoteParticipants {
            for participant in participants {
                self.participants.append(ObservableParticipant(participant.value))
            }
        }
    }

    deinit {
        room?.remove(delegate: self)
        print("RoomViewCtrl deinit \(id)")
    }

    func room(_ room: Room, participant: RemoteParticipant, didSubscribe trackPublication: RemoteTrackPublication, track: Track) {
        print("RoomViewCtrl didSubscribe \(track)")
    }
}

struct ParticipantView: View {

    @ObservedObject var participant: ObservableParticipant

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background color
            Color.white
                .opacity(0.3)
                .ignoresSafeArea()

            // VideoView for the Participant
            if let track = participant.firstVideoTrack {
                SwiftUIVideoView(track: track)
            }

            Text(participant.identity ?? "-")
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .border(Color.blue.opacity(0.5),
                width: participant.isSpeaking ? 5.0 : 0.0)
    }
}

struct RoomView: View {

    @ObservedObject var ctrl = RoomViewCtrl()

    var columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {

        ScrollView(.vertical, showsIndicators: true) {
            LazyVGrid(columns: columns,
                      alignment: .center,
                      spacing: 10,
                      pinnedViews: .sectionFooters) {
                ForEach(ctrl.participants) { participant in
                    ParticipantView(participant: participant)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding()
        }
    }
}
