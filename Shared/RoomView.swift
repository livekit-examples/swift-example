import SwiftUI
import LiveKit

struct RoomView: View {

    @EnvironmentObject var appCtrl: AppCtrl
    @ObservedObject var observableRoom: ObservableRoom

    init(_ room: Room) {
        observableRoom = ObservableRoom(room: room)
    }

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
                ForEach(observableRoom.participants.values) { participant in
                    ParticipantView(participant: participant)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    Button(action: {
                        observableRoom.togglePublishCamera()
                    },
                    label: {
                        Image(systemName: "video.fill").foregroundColor(
                            observableRoom.localVideo != nil ? Color.green : nil
                        )
                    })

                    Button(action: {
                        observableRoom.togglePublishMicrophone()
                    },
                    label: {
                        Image(systemName: "mic.fill").foregroundColor(
                            observableRoom.localAudio != nil ? Color.orange : nil
                        )
                    })

                    Button(action: {
                        appCtrl.disconnect()
                    },
                    label: {
                        Image(systemName: "bolt.horizontal.circle.fill")
                    })

                }
            }
        }
    }
}
