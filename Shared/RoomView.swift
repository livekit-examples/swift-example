import SwiftUI
import LiveKit

struct MenuChoice: Identifiable {
    let id = UUID()
    let title: String
}

let mainMenu = [
    MenuChoice(title: "Choice 1"),
    MenuChoice(title: "Choice 2"),
    MenuChoice(title: "Choice 3"),
]

final class ObservableParticipant: ObservableObject, Identifiable, ParticipantDelegate {

    let participant: Participant

    // Identifiable
    var id: String {
        participant.sid
    }

    init(_ participant: Participant) {
        self.participant = participant
        participant.add(delegate: self)
    }

    deinit {
        participant.remove(delegate: self)
    }
}

final class RoomViewCtrl: ObservableObject, RoomDelegate {

    let id = UUID()
    let room = AppCtrl.shared.room

    var participants: [ObservableParticipant] = []

    init() {
        print("RoomViewCtrl init \(id)")

        room?.add(delegate: self)
//        let count = room?.remoteParticipants.count

        if let participants = room?.remoteParticipants {
            //
            for p in participants {
                self.participants.append(ObservableParticipant(p.value))
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

struct VideoView2: UIViewRepresentable {
    let videoTrack: VideoTrack
    func makeUIView(context: Context) -> VideoView {
//        let control = UIPageControl()
//        control.numberOfPages = numberOfPages
        let view = VideoView()
        videoTrack.addRenderer(view.rendererView)
        return view
    }

    func updateUIView(_ uiView: VideoView, context: Context) {
//        uiView.currentPage = VideoView
    }
}

struct ParticipantView: View {
    @ObservedObject var participant: ObservableParticipant
    var body: some View {
        VStack {
            Text("Participant").frame(alignment: .center)
            if let track = participant.participant.videoTracks.values.first {
//                Text("has video \(track.sid)")

                VideoView2(videoTrack: track.track as! VideoTrack).frame(minWidth: 100, minHeight: 100)
            }
        }
    }
}

struct RoomView: View {

    @ObservedObject var ctrl = RoomViewCtrl()

    var rows = [
        GridItem(.flexible()),
    ]

    var body: some View {
        VStack {
            Text("Connect to LiveKit")

            ScrollView(.horizontal, showsIndicators: true) {
                LazyHGrid(rows: rows,
                          alignment: .center,
                          spacing: 10,
                          pinnedViews: .sectionFooters) {
                    ForEach(ctrl.participants) { item in
                        ParticipantView(participant: item)
                    }
                }
            }
            .frame(maxWidth: 500)
//            List(mainMenu) { item in
//                NavigationLink(destination: RoomView()) {
//                    Text("Item: \(item.title)")
//                }
//            }
        }
    }
}
