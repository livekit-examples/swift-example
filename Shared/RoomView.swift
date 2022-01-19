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
                .background(isMe ? Color.lkBlue : Color.gray)
                .foregroundColor(isMe ? Color.white : Color.black)
                .cornerRadius(12)
            //            }
        }.padding(.vertical, 5)
        .padding(.horizontal, 10)
    }

    func scrollToBottom(_ scrollView: ScrollViewProxy) {
        guard let last = observableRoom.messages.last else { return }
        withAnimation {
            scrollView.scrollTo(last.id)
        }
    }

    func messagesView(geometry: GeometryProxy) -> some View {

        VStack(spacing: 0) {
            ScrollViewReader { scrollView in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(observableRoom.messages) {
                            messageView($0)
                        }
                    }
                }
                .onAppear(perform: {
                    // Scroll to bottom when first showing the messages list
                    scrollToBottom(scrollView)
                })
                .onChange(of: observableRoom.messages, perform: { _ in
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
            .background(Color.lkBlue)
        }.background(Color.lkDarkBlue)
        .frame(
            minWidth: 0,
            maxWidth: geometry.isTall ? .infinity : 320
        )
    }

    func content(geometry: GeometryProxy) -> some View {

        HorVStack(axis: geometry.isWide ? .horizontal : .vertical) {

            Group {
                if let focusParticipant = observableRoom.focusParticipant {
                    ParticipantView(participant: focusParticipant,
                                    videoViewMode: videoViewMode, onTap: ({ _ in
                                        observableRoom.focusParticipant = nil
                                    })).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVGrid(columns: columns,
                                  alignment: .center,
                                  spacing: 10) {
                            ForEach(observableRoom.allParticipants.values) { participant in
                                ParticipantView(participant: participant,
                                                videoViewMode: videoViewMode, onTap: ({ participant in
                                                    observableRoom.focusParticipant = participant
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
            if observableRoom.showMessagesView {
                messagesView(geometry: geometry)
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
                            if !observableRoom.cameraTrackState.isPublished || !CameraCapturer.canSwitchPosition() {
                                Button(action: {
                                    observableRoom.toggleCameraEnabled()
                                },
                                label: {
                                    Image(systemName: "video.fill")
                                        .foregroundColor(
                                            observableRoom.cameraTrackState.isPublished  ? Color.green : nil
                                        )
                                })
                                // disable while publishing/un-publishing
                                .disabled(observableRoom.cameraTrackState.isBusy)
                            } else {
                                Menu {
                                    Button("Switch position") {
                                        observableRoom.switchCameraPosition()
                                    }
                                    Button("Disable") {
                                        observableRoom.toggleCameraEnabled()
                                    }
                                } label: {
                                    Image(systemName: "video.fill").foregroundColor(Color.green)
                                }
                            }

                            // Toggle microphone enabled
                            Button(action: {
                                observableRoom.toggleMicrophoneEnabled()
                            },
                            label: {
                                Image(systemName: "mic.fill").foregroundColor(
                                    observableRoom.microphoneTrackState.isPublished ? Color.orange : nil
                                )
                            })
                            // disable while publishing/un-publishing
                            .disabled(observableRoom.microphoneTrackState.isBusy)

                            #if os(iOS)
                            Button(action: {
                                observableRoom.toggleScreenShareEnabled()
                            },
                            label: {
                                Image(systemName: "rectangle.fill.on.rectangle.fill").foregroundColor(
                                    observableRoom.screenShareTrackState.isPublished ? Color.green : nil
                                )
                            })
                            #elseif os(macOS)
                            Button(action: {
                                if observableRoom.screenShareTrackState.isPublished {
                                    // turn off screen share
                                    observableRoom.toggleScreenShareEnabled(screenShareSource: nil)
                                } else {
                                    screenPickerPresented = true
                                }
                            },
                            label: {
                                Image(systemName: "rectangle.fill.on.rectangle.fill").foregroundColor(
                                    observableRoom.screenShareTrackState.isPublished ? Color.green : nil
                                )
                            }).popover(isPresented: $screenPickerPresented) {
                                ScreenShareSourcePickerView { source in
                                    observableRoom.toggleScreenShareEnabled(screenShareSource: source)
                                    screenPickerPresented = false
                                }.padding()
                            }
                            #endif

                            // Toggle messages view (chat example)
                            Button(action: {
                                withAnimation {
                                    observableRoom.showMessagesView.toggle()
                                }
                            },
                            label: {
                                Image(systemName: "message.fill")
                                    .foregroundColor(observableRoom.showMessagesView ? Color.blue : nil)
                            })

                        }

                        Spacer()

                        Menu {
                            Toggle("Video Information", isOn: $debugCtrl.showInformation)
                            Toggle("Video View", isOn: $debugCtrl.videoViewVisible)
                        } label: {
                            Image(systemName: "ladybug.fill")
                        }

                        Spacer()

                        // Disconnect
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

    var isTall: Bool {
        size.height > size.width
    }

    var isWide: Bool {
        size.width > size.height
    }
}
