import SwiftUI
import LiveKit

#if !os(macOS)
let adaptiveMin = 170.0
let toolbarPlacement: ToolbarItemPlacement = .bottomBar
#else
let adaptiveMin = 300.0
let toolbarPlacement: ToolbarItemPlacement = .primaryAction
#endif

struct RoomView: View {

    @EnvironmentObject var appCtrl: AppCtrl
    @ObservedObject var observableRoom: ObservableRoom

    @State private var videoViewMode: VideoView.Mode = .fill

    init(_ room: Room) {
        observableRoom = ObservableRoom(room)
    }

    var columns = [
        GridItem(.adaptive(minimum: adaptiveMin))
    ]

    var body: some View {

        ScrollView(.vertical, showsIndicators: true) {
            LazyVGrid(columns: columns,
                      alignment: .center,
                      spacing: 10) {
                ForEach(observableRoom.allParticipants.values) { participant in
                    ParticipantView(participant: participant, videoViewMode: videoViewMode)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: toolbarPlacement) {
                HStack {

                    Picker("Mode", selection: $videoViewMode) {
                        Text("Fit").tag(VideoView.Mode.fit)
                        Text("Fill").tag(VideoView.Mode.fill)
                    }
                    .pickerStyle(.segmented)

                    Spacer()
                    
                    if observableRoom.localVideo != nil {
                        Menu {
                            Button("Office 1") {
                                observableRoom.backgroundImage = CIImage(data: NSImage(named: "bg-1")!.tiffRepresentation!)
                            }
                            Button("Space") {
                                observableRoom.backgroundImage = CIImage(data: NSImage(named: "bg-2")!.tiffRepresentation!)
                            }
                            Button("Thailand") {
                                observableRoom.backgroundImage = CIImage(data: NSImage(named: "bg-3")!.tiffRepresentation!)
                            }
                            Button("No background") {
                                observableRoom.backgroundImage = nil
                            }
                        } label: {
                            Image(systemName: "photo.artframe")
                        }
                    }


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
                        Image(systemName: "xmark.circle")
                            .foregroundColor(nil)
                    })

                }
            }
        }
    }
}
