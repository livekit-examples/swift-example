import SwiftUI
import LiveKit

#if !os(macOS)
let adaptiveMin = 170.0
let toolbarPlacement: ToolbarItemPlacement = .bottomBar
#else
let adaptiveMin = 300.0
let toolbarPlacement: ToolbarItemPlacement = .primaryAction
#endif

extension CIImage {
    convenience init(named name: String) {
#if !os(macOS)
        self.init(cgImage: UIImage(named: name)!.cgImage!)
#else
        self.init(data: NSImage(named: name)!.tiffRepresentation!)!
#endif
    }
}

struct RoomView: View {

    @EnvironmentObject var appCtrl: AppCtrl
    @ObservedObject var observableRoom: ObservableRoom

    @State private var videoViewMode: VideoView.Mode = .fill
    
    // Debug purpose
    @State private var videoViewVisible: Bool = true

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
                    ParticipantView(participant: participant,
                                    videoViewMode: videoViewMode,
                                    videoViewVisible: videoViewVisible)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItemGroup(placement: toolbarPlacement) {
        
                    Picker("Mode", selection: $videoViewMode) {
                        Text("Fit").tag(VideoView.Mode.fit)
                        Text("Fill").tag(VideoView.Mode.fill)
                    }
                    .pickerStyle(.segmented)

                    Spacer()
                    
                    if observableRoom.localVideo != nil {
                        Menu {
                            Button("Office 1") {
                                observableRoom.backgroundImage = CIImage(named: "bg-1")
                            }
                            Button("Space") {
                                observableRoom.backgroundImage = CIImage(named: "bg-2")
                            }
                            Button("Thailand") {
                                observableRoom.backgroundImage = CIImage(named: "bg-3")
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
                    
                    Spacer()
                    
                    Menu {
                        Button("Toggle Video View") {
                            videoViewVisible.toggle()
                        }
                    } label: {
                        Image(systemName: "ladybug.fill")
                    }
                
                    Spacer()
                    
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
