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

    @EnvironmentObject var appCtrl: AppContextCtrl
    @EnvironmentObject var room: ExampleObservableRoom
    @EnvironmentObject var debugCtrl: DebugCtrl

    @State private var videoViewMode: VideoView.Mode = .fill
    @State private var screenPickerPresented = false

    var columns = [
        GridItem(.adaptive(minimum: CGFloat(adaptiveMin)))
    ]

    func messageView(_ message: ExampleRoomMessage) -> some View {

        let isMe = message.senderSid == room.room.localParticipant?.sid

        return HStack {
            if isMe {
                Spacer()
            }

            //            VStack(alignment: isMe ? .trailing : .leading) {
            //                Text(message.identity)
            Text(message.text)
                .padding(8)
                .background(isMe ? Color.lkBlue : Color.gray)
                .foregroundColor(isMe ? Color.white : Color.black)
                .cornerRadius(12)
            //            }
        }.padding(.vertical, 5)
        .padding(.horizontal, 10)
    }

    func scrollToBottom(_ scrollView: ScrollViewProxy) {
        guard let last = room.messages.last else { return }
        withAnimation {
            scrollView.scrollTo(last.id)
        }
    }

    func messagesView(geometry: GeometryProxy) -> some View {

        VStack(spacing: 0) {
            ScrollViewReader { scrollView in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(room.messages) {
                            messageView($0)
                        }
                    }
                }
                .onAppear(perform: {
                    // Scroll to bottom when first showing the messages list
                    scrollToBottom(scrollView)
                })
                .onChange(of: room.messages, perform: { _ in
                    // Scroll to bottom when there is a new message
                    scrollToBottom(scrollView)
                })
                .frame(
                    minWidth: 0,
                    maxWidth: .infinity,
                    minHeight: 0,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
            }
            HStack(spacing: 0) {

                TextField("Enter message", text: $room.textFieldString)
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

                Button {
                    room.sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(room.textFieldString.isEmpty ? nil : Color.blue)
                }
                .buttonStyle(.borderless)

            }.padding()
            .background(Color.lkBlue)
        }.background(Color.lkDarkBlue)
        .frame(
            minWidth: 0,
            maxWidth: geometry.isTall ? .infinity : 320
        )
    }

    func content(geometry: GeometryProxy) -> some View {

        VStack {

            if case .connecting(let connectMode) = appCtrl.connectionState,
               case .reconnect(let reconnectMode) = connectMode {
                Text("Re-connecting(\(String(describing: reconnectMode)))...")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding()
            }

            HorVStack(axis: geometry.isWide ? .horizontal : .vertical) {

                Group {
                    if let focusParticipant = room.focusParticipant {
                        ParticipantView(participant: focusParticipant,
                                        videoViewMode: videoViewMode, onTap: ({ _ in
                                            room.focusParticipant = nil
                                        })).frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVGrid(columns: columns,
                                      alignment: .center,
                                      spacing: 10) {
                                ForEach(room.allParticipants.values) { participant in
                                    ParticipantView(participant: participant,
                                                    videoViewMode: videoViewMode, onTap: ({ participant in
                                                        room.focusParticipant = participant
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
                // Show messages view if enabled
                if room.showMessagesView {
                    messagesView(geometry: geometry)
                }
            }
        }
    }

    var body: some View {

        GeometryReader { geometry in
            content(geometry: geometry)
                .toolbar {
                    ToolbarItemGroup(placement: toolbarPlacement) {

                        // VideoView mode switcher
                        Picker("Mode", selection: $videoViewMode) {
                            Text("Fit").tag(VideoView.Mode.fit)
                            Text("Fill").tag(VideoView.Mode.fill)
                        }
                        .pickerStyle(SegmentedPickerStyle())

                        Spacer()

                        Group {

                            // Toggle camera enabled
                            if !room.cameraTrackState.isPublished || !CameraCapturer.canSwitchPosition() {
                                Button(action: {
                                    room.toggleCameraEnabled()
                                },
                                label: {
                                    Image(systemName: "video.fill")
                                        .renderingMode(room.cameraTrackState.isPublished ? .original : .template)
                                })
                                // disable while publishing/un-publishing
                                .disabled(room.cameraTrackState.isBusy)
                            } else {
                                Menu {
                                    Button("Switch position") {
                                        room.switchCameraPosition()
                                    }
                                    Button("Disable") {
                                        room.toggleCameraEnabled()
                                    }
                                } label: {
                                    Image(systemName: "video.fill")
                                        .renderingMode(.original)
                                }
                            }

                            // Toggle microphone enabled
                            Button(action: {
                                room.toggleMicrophoneEnabled()
                            },
                            label: {
                                Image(systemName: "mic.fill")
                                    .renderingMode(room.microphoneTrackState.isPublished ? .original : .template)
                            })
                            // disable while publishing/un-publishing
                            .disabled(room.microphoneTrackState.isBusy)

                            #if os(iOS)
                            Button(action: {
                                room.toggleScreenShareEnabled()
                            },
                            label: {
                                Image(systemName: "rectangle.fill.on.rectangle.fill")
                                    .renderingMode(room.screenShareTrackState.isPublished ? .original : .template)
                            })
                            #elseif os(macOS)
                            Button(action: {
                                if room.screenShareTrackState.isPublished {
                                    // turn off screen share
                                    room.toggleScreenShareEnabled(screenShareSource: nil)
                                } else {
                                    screenPickerPresented = true
                                }
                            },
                            label: {
                                Image(systemName: "rectangle.fill.on.rectangle.fill")
                                    .renderingMode(room.screenShareTrackState.isPublished ? .original : .template)
                            }).popover(isPresented: $screenPickerPresented) {
                                ScreenShareSourcePickerView { source in
                                    room.toggleScreenShareEnabled(screenShareSource: source)
                                    screenPickerPresented = false
                                }.padding()
                            }
                            #endif

                            // Toggle messages view (chat example)
                            Button(action: {
                                withAnimation {
                                    room.showMessagesView.toggle()
                                }
                            },
                            label: {
                                Image(systemName: "message.fill")
                                    .renderingMode(room.showMessagesView ? .original : .template)
                            })

                        }

                        Spacer()

                        Menu {
                            Toggle("Show video information", isOn: $debugCtrl.showInformation)
                            Toggle("Use video view", isOn: $debugCtrl.videoViewVisible)

                            Menu {
                                Button {
                                    appCtrl.room.room.sendSimulate(scenario: .nodeFailure)
                                } label: {
                                    Text("Node failure")
                                }

                                Button {
                                    appCtrl.room.room.sendSimulate(scenario: .serverLeave)
                                } label: {
                                    Text("Server leave")
                                }

                                Button {
                                    appCtrl.room.room.sendSimulate(scenario: .migration)
                                } label: {
                                    Text("Migration")
                                }

                                Button {
                                    appCtrl.room.room.sendSimulate(scenario: .speakerUpdate(seconds: 3))
                                } label: {
                                    Text("Speaker update")
                                }

                            } label: {
                                Text("Simulate scenario")
                            }
                        } label: {
                            Image(systemName: "ladybug.fill")
                                .renderingMode(.original)
                        }

                        Spacer()

                        // Disconnect
                        Button(action: {
                            appCtrl.disconnect()
                        },
                        label: {
                            Image(systemName: "xmark.circle.fill")
                                .renderingMode(.original)
                        })
                    }

                }
        }
    }
}

struct HorVStack<Content: View>: View {
    let axis: Axis
    let horizontalAlignment: HorizontalAlignment
    let verticalAlignment: VerticalAlignment
    let spacing: CGFloat?
    let content: () -> Content

    init(axis: Axis = .horizontal,
         horizontalAlignment: HorizontalAlignment = .center,
         verticalAlignment: VerticalAlignment = .center,
         spacing: CGFloat? = nil,
         @ViewBuilder content: @escaping () -> Content) {

        self.axis = axis
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        Group {
            if axis == .vertical {
                VStack(alignment: horizontalAlignment, spacing: spacing, content: content)
            } else {
                HStack(alignment: verticalAlignment, spacing: spacing, content: content)
            }
        }
    }
}

extension GeometryProxy {

    public var isTall: Bool {
        size.height > size.width
    }

    var isWide: Bool {
        size.width > size.height
    }
}
