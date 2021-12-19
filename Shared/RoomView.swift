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
    // helper to create a `CIImage` for both platforms
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
    @EnvironmentObject var debugCtrl: DebugCtrl
    @ObservedObject var observableRoom: ExampleObservableRoom

    @State private var videoViewMode: VideoView.Mode = .fill
    @State private var focusParticipant: ObservableParticipant?

    @State private var screenPickerPresented = false

    init(_ room: Room) {
        observableRoom = ExampleObservableRoom(room)
    }

    var columns = [
        GridItem(.adaptive(minimum: CGFloat(adaptiveMin)))
    ]

    func messageView(_ message: RoomMessage) -> some View {

        let isMe = message.senderSid == observableRoom.room.localParticipant?.sid

        return HStack {
            if isMe {
                Spacer()
            }
    
//            VStack(alignment: isMe ? .trailing : .leading) {
//                Text(message.identity)
                Text(message.text)
                    .padding(8)
                    .background(isMe ? Color.lkBlue : Color.white)
                    .foregroundColor(isMe ? Color.white : Color.black)
                    .clipShape(Capsule())
//            }
        }
    }

    func messagesView() -> some View {
        VStack {
            ScrollViewReader { scrollView in
                List {
                    ForEach(observableRoom.messages) {
                        messageView($0)
                    }
                }
            .onChange(of: observableRoom.messages, perform: { newValue in
                print("onChange! \(scrollView)")
                guard let last = observableRoom.messages.last else { return }
                withAnimation {
                    scrollView.scrollTo(last.id)
                }
            })
            .frame(
                minWidth: 0,
                maxWidth: .infinity,
                minHeight: 0,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            }
            HStack(spacing: 10) {

                TextField("Enter message", text: $observableRoom.textFieldString)
                    .textFieldStyle(PlainTextFieldStyle())
                    .disableAutocorrection(true)
                // TODO: add iOS unique view modifiers
                // #if os(iOS)
                // .autocapitalization(.none)
                // .keyboardType(type.toiOSType())
                // #endif

                //                    .overlay(RoundedRectangle(cornerRadius: 10.0)
                //                                .strokeBorder(Color.white.opacity(0.3),
                //                                              style: StrokeStyle(lineWidth: 1.0)))

                Button(action: {
                    observableRoom.sendMessage()
                },
                label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(observableRoom.textFieldString.isEmpty ? nil : Color.blue)
                })

            }.padding()
            .background(Color.red)
            .frame(height: 100)
        }.background(Color.lkDarkBlue)
        .frame(width: 320)
    }

    func content() -> some View {

        HStack {
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
                                                    self.focusParticipant = participant
                                                })).aspectRatio(1, contentMode: .fit)
                            }
                        }.padding()
                    }
                }
            }
            .frame(
                minWidth: 0,
                maxWidth: .infinity,
                minHeight: 0,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            if observableRoom.showMessagesView {
                messagesView()
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
                    .pickerStyle(SegmentedPickerStyle())

                    Spacer()

                    // Background swapping example
                    // Compiling with Xcode13+ and iOS15+ or macOS12+ is required.
                    #if swift(>=5.5)
                    if #available(iOS 15, macOS 12, *) {
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
                    }
                    #endif

                    if !CameraCapturer.canSwitchPosition() || observableRoom.localVideo == nil {
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

                    #if os(iOS)
                    Button(action: {
                        observableRoom.toggleScreenEnabled()
                    },
                    label: {
                        Image(systemName: "rectangle.fill.on.rectangle.fill").foregroundColor(
                            observableRoom.localScreen != nil ? Color.green : nil
                        )
                    })
                    #elseif os(macOS)
                    Button(action: {
                        if observableRoom.localScreen != nil {
                            // turn off screen share
                            observableRoom.toggleScreenEnabled()
                        } else {
                            screenPickerPresented = true
                        }
                    },
                    label: {
                        Image(systemName: "rectangle.fill.on.rectangle.fill").foregroundColor(
                            observableRoom.localScreen != nil ? Color.green : nil
                        )
                    }).popover(isPresented: $screenPickerPresented) {
                        ScreenShareSourcePickerView { source in
                            observableRoom.toggleScreenEnabled(source)
                            screenPickerPresented = false
                        }.padding()
                    }
                    #endif

                    Spacer()

                    Menu {
                        Toggle("Video Information", isOn: $debugCtrl.showInformation)
                        Toggle("Video View", isOn: $debugCtrl.videoViewVisible)
                    } label: {
                        Image(systemName: "ladybug.fill")
                    }

                    Spacer()

                    Group {

                        Button(action: {
                            withAnimation {
                                observableRoom.showMessagesView.toggle()
                            }
                        },
                        label: {
                            Image(systemName: "message.fill")
                                .foregroundColor(nil)
                        })

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
}
