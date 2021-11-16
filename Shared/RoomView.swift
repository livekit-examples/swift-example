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

final class DebugCtrl: ObservableObject {
    // Debug purpose
    @Published var videoViewVisible: Bool = true
    @Published var showInformation: Bool = false
}

struct RoomView: View {

    @EnvironmentObject var appCtrl: AppCtrl
    @EnvironmentObject var debugCtrl: DebugCtrl
    @ObservedObject var observableRoom: ExampleObservableRoom

    @State private var videoViewMode: VideoView.Mode = .fill
    @State private var focusParticipant: ObservableParticipant?

    init(_ room: Room) {
        observableRoom = ExampleObservableRoom(room)
    }

    var columns = [
        GridItem(.adaptive(minimum: adaptiveMin))
    ]

    func content() -> some View {
        Group {
            if let focusParticipant = focusParticipant {
                ParticipantView(participant: focusParticipant,
                                videoViewMode: videoViewMode, onTap: ({ _ in
                                    self.focusParticipant = nil
                                })).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVGrid(columns: columns,
                              alignment: .center,
                              spacing: 10) {
                        ForEach(observableRoom.allParticipants.values) { participant in
                            ParticipantView(participant: participant,
                                            videoViewMode: videoViewMode, onTap: ({ participant in
                                                print("did tap!!")
                                                self.focusParticipant = participant
                                            })).aspectRatio(1, contentMode: .fit)
                        }
                    }.padding()
                }
            }
        }
    }

    var body: some View {

        content()
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
                                observableRoom.background = .office
                            }
                            Button("Space") {
                                observableRoom.background = .space
                            }
                            Button("Thailand") {
                                observableRoom.background = .thailand
                            }
                            Button("No background") {
                                observableRoom.background = .none
                            }
                        } label: {
                            Image(systemName: "photo.artframe")
                        }
                    }

                    if !CameraCapturer.canTogglePosition() || observableRoom.localVideo == nil {
                        Button(action: {
                            observableRoom.toggleCameraEnabled()
                        },
                        label: {
                            Image(systemName: "video.fill").foregroundColor(
                                observableRoom.localVideo != nil ? Color.green : nil
                            )
                        })
                    } else {
                        Menu {
                            Button("Switch position") {
                                observableRoom.toggleCameraPosition()
                            }
                            Button("Disable") {
                                observableRoom.toggleCameraEnabled()
                            }
                        } label: {
                            Image(systemName: "video.fill").foregroundColor(Color.green)
                        }
                    }

                    Button(action: {
                        observableRoom.toggleMicrophoneEnabled()
                    },
                    label: {
                        Image(systemName: "mic.fill").foregroundColor(
                            observableRoom.localAudio != nil ? Color.orange : nil
                        )
                    })

                    Button(action: {
                        observableRoom.toggleScreenEnabled()
                    },
                    label: {
                        Image(systemName: "rectangle.fill.on.rectangle.fill").foregroundColor(
                            observableRoom.localScreen != nil ? Color.green : nil
                        )
                    })

                    Spacer()

                    Menu {
                        Toggle("Video Information", isOn: $debugCtrl.showInformation)
                        Toggle("Video View", isOn: $debugCtrl.videoViewVisible)
                    } label: {
                        Image(systemName: "ladybug.fill")
                    }

                    Spacer()

                    Button(action: {
                        appCtrl.disconnect()
                    },
                    label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(nil)
                    })

                }

            }
    }
}
