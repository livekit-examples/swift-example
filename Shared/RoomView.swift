import SwiftUI
import LiveKit
import SFSafeSymbols
import WebRTC

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

extension RTCIODevice: Identifiable {

    public var id: String {
        deviceId
    }
}

#if os(macOS)
// keeps weak reference to NSWindow
class WindowAccess: ObservableObject {

    private weak var window: NSWindow?

    deinit {
        // reset changed properties
        DispatchQueue.main.async { [weak window] in
            window?.level = .normal
        }
    }

    @Published public var pinned: Bool = false {
        didSet {
            guard oldValue != pinned else { return }
            self.level = pinned ? .floating : .normal
        }
    }

    private var level: NSWindow.Level {
        get { window?.level ?? .normal }
        set {
            DispatchQueue.main.async {
                self.window?.level = newValue
                self.objectWillChange.send()
            }
        }
    }

    public func set(window: NSWindow?) {
        self.window = window
        DispatchQueue.main.async { self.objectWillChange.send() }
    }
}
#endif

struct RoomView: View {

    @EnvironmentObject var appCtx: AppContext
    @EnvironmentObject var roomCtx: RoomContext
    @EnvironmentObject var room: ExampleObservableRoom

    @State private var screenPickerPresented = false
    #if os(macOS)
    @ObservedObject private var windowAccess = WindowAccess()
    #endif

    // @State private var itemCount = 0.0

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
                    LazyVStack(alignment: .center, spacing: 0) {
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
                    Image(systemSymbol: .paperplaneFill)
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
            if case .connecting(let connectMode) = roomCtx.connectionState,
               case .reconnect(let reconnectMode) = connectMode {
                Text("Re-connecting(\(String(describing: reconnectMode)))...")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding()
            }

            HorVStack(axis: geometry.isTall ? .vertical : .horizontal, spacing: 5) {

                Group {
                    if let focusParticipant = room.focusParticipant {
                        ZStack(alignment: .topTrailing) {
                            ParticipantView(participant: focusParticipant,
                                            videoViewMode: appCtx.videoViewMode) { _ in
                                room.focusParticipant = nil
                            }
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 5.0))
                            Text("FOCUSED")
                                .font(.system(size: 10))
                                .fontWeight(.bold)
                                .foregroundColor(Color.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.3))
                                .cornerRadius(8)
                                .padding()
                        }
                    } else {
                        ParticipantLayout(room.allParticipants.values, spacing: 5) { participant in
                            ParticipantView(participant: participant,
                                            videoViewMode: appCtx.videoViewMode) { participant in
                                room.focusParticipant = participant

                            }
                        }
                    }
                }
                .frame(
                    minWidth: 0,
                    maxWidth: .infinity,
                    minHeight: 0,
                    maxHeight: .infinity
                )
                // Show messages view if enabled
                if room.showMessagesView {
                    messagesView(geometry: geometry)
                }
            }
        }
        .padding(5)
    }

    var body: some View {

        GeometryReader { geometry in
            content(geometry: geometry)
                .toolbar {
                    ToolbarItemGroup(placement: toolbarPlacement) {

                        #if os(macOS)
                        if let name = room.room.name {
                            Text(name)
                                .fontWeight(.bold)
                        }

                        if let identity = room.room.localParticipant?.identity {
                            Text(identity)
                        }
                        #endif

                        #if os(macOS)
                        // Pin on top
                        Toggle(isOn: $windowAccess.pinned) {
                            Image(systemSymbol: windowAccess.pinned ? .pinFill : .pin)
                                .renderingMode(.original)
                        }
                        #endif

                        // VideoView mode switcher
                        Picker("Mode", selection: $appCtx.videoViewMode) {
                            Text("Fit").tag(VideoView.LayoutMode.fit)
                            Text("Fill").tag(VideoView.LayoutMode.fill)
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
                                    Image(systemSymbol: .videoFill)
                                        .renderingMode(room.cameraTrackState.isPublished ? .original : .template)
                                })
                                // disable while publishing/un-publishing
                                .disabled(room.cameraTrackState.isBusy)
                            } else {
                                Menu {
                                    Button("Switch position") {
                                        room.switchCameraPosition().then { _ in
                                            //
                                        }
                                    }
                                    Button("Disable") {
                                        room.toggleCameraEnabled()
                                    }
                                } label: {
                                    Image(systemSymbol: .videoFill)
                                        .renderingMode(.original)
                                }
                            }

                            // Toggle microphone enabled
                            Button(action: {
                                room.toggleMicrophoneEnabled()
                            },
                            label: {
                                Image(systemSymbol: .micFill)
                                    .renderingMode(room.microphoneTrackState.isPublished ? .original : .template)
                            })
                            // disable while publishing/un-publishing
                            .disabled(room.microphoneTrackState.isBusy)

                            #if os(iOS)
                            Button(action: {
                                room.toggleScreenShareEnabled(screenShareSource: nil)
                            },
                            label: {
                                Image(systemSymbol: .rectangleFillOnRectangleFill)
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
                                Image(systemSymbol: .rectangleFillOnRectangleFill)
                                    .renderingMode(room.screenShareTrackState.isPublished ? .original : .template)
                                    .foregroundColor(room.screenShareTrackState.isPublished ? Color.green : Color.white)
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
                                Image(systemSymbol: .messageFill)
                                    .renderingMode(room.showMessagesView ? .original : .template)
                            })

                        }

                        Spacer()

                        Group {

                            Menu {

                                #if os(macOS)
                                Button {
                                    if let url = URL(string: "livekit://") {
                                        NSWorkspace.shared.open(url)
                                    }
                                } label: {
                                    Text("New window")
                                }
                                #endif

                                Toggle("Show info", isOn: $appCtx.showInformationOverlay)

                                Divider()

                                Group {

                                    Picker("Output device", selection: $appCtx.playoutDevice) {
                                        ForEach(Room.audioDeviceModule().playoutDevices) { device in
                                            Text(device.isDefault ? "Default" : "\(device.name)").tag(device)
                                        }
                                    }

                                    Picker("Recording device", selection: $appCtx.recordingDevice) {
                                        ForEach(Room.audioDeviceModule().recordingDevices) { device in
                                            Text(device.isDefault ? "Default" : "\(device.name)").tag(device)
                                        }
                                    }
                                }

                                Divider()

                                Group {
                                    Toggle("VideoView visible", isOn: $appCtx.videoViewVisible)
                                    Toggle("VideoView preferMetal", isOn: $appCtx.preferMetal)
                                    Toggle("VideoView flip", isOn: $appCtx.videoViewMirrored)
                                }

                                Divider()

                                Menu {
                                    Button {
                                        roomCtx.room.room.sendSimulate(scenario: .nodeFailure)
                                    } label: {
                                        Text("Node failure")
                                    }

                                    Button {
                                        roomCtx.room.room.sendSimulate(scenario: .serverLeave)
                                    } label: {
                                        Text("Server leave")
                                    }

                                    Button {
                                        roomCtx.room.room.sendSimulate(scenario: .migration)
                                    } label: {
                                        Text("Migration")
                                    }

                                    Button {
                                        roomCtx.room.room.sendSimulate(scenario: .speakerUpdate(seconds: 3))
                                    } label: {
                                        Text("Speaker update")
                                    }

                                } label: {
                                    Text("Simulate scenario")
                                }

                                Menu {
                                    Button {
                                        roomCtx.room.room.localParticipant?.setTrackSubscriptionPermissions(allParticipantsAllowed: true)
                                    } label: {
                                        Text("Allow all")
                                    }

                                    Button {
                                        roomCtx.room.room.localParticipant?.setTrackSubscriptionPermissions(allParticipantsAllowed: false)
                                    } label: {
                                        Text("Disallow all")
                                    }
                                } label: {
                                    Text("Track permissions")
                                }

                            } label: {
                                Image(systemSymbol: .gear)
                                    .renderingMode(.original)
                            }

                            // Disconnect
                            Button(action: {
                                roomCtx.disconnect()
                            },
                            label: {
                                Image(systemSymbol: .xmarkCircleFill)
                                    .renderingMode(.original)
                            })
                        }
                    }

                }
        }
        #if os(macOS)
        .withHostingWindow { self.windowAccess.set(window: $0) }
        #endif
    }
}

struct ParticipantLayout<Content: View>: View {

    let views: [AnyView]
    let spacing: CGFloat

    init<Data: RandomAccessCollection>(
        _ data: Data,
        id: KeyPath<Data.Element, Data.Element> = \.self,
        spacing: CGFloat,
        @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.spacing = spacing
        self.views = data.map { AnyView(content($0[keyPath: id])) }
    }

    func computeColumn(with geometry: GeometryProxy) -> (x: Int, y: Int) {
        let sqr = Double(views.count).squareRoot()
        let r: [Int] = [Int(sqr.rounded()), Int(sqr.rounded(.up))]
        let c = geometry.isTall ? r : r.reversed()
        return (x: c[0], y: c[1])
    }

    func grid(axis: Axis, geometry: GeometryProxy) -> some View {
        ScrollView([ axis == .vertical ? .vertical : .horizontal ]) {
            HorVGrid(axis: axis, columns: [GridItem(.flexible())], spacing: spacing) {
                ForEach(0..<views.count, id: \.self) { i in
                    views[i]
                        .aspectRatio(1, contentMode: .fill)
                }
            }
            .padding(axis == .horizontal ? [.leading, .trailing] : [.top, .bottom],
                     max(0, ((axis == .horizontal ? geometry.size.width : geometry.size.height)
                                - ((axis == .horizontal ? geometry.size.height : geometry.size.width) * CGFloat(views.count)) - (spacing * CGFloat(views.count - 1))) / 2))
        }
    }

    var body: some View {
        GeometryReader { geometry in
            if views.isEmpty {
                EmptyView()
            } else if geometry.size.width <= 300 {
                grid(axis: .vertical, geometry: geometry)
            } else if geometry.size.height <= 300 {
                grid(axis: .horizontal, geometry: geometry)
            } else {

                let verticalWhenTall: Axis = geometry.isTall ? .vertical : .horizontal
                let horizontalWhenTall: Axis = geometry.isTall ? .horizontal : .vertical

                switch views.count {
                // simply return first view
                case 1: views[0]
                case 3: HorVStack(axis: verticalWhenTall, spacing: spacing) {
                    views[0]
                    HorVStack(axis: horizontalWhenTall, spacing: spacing) {
                        views[1]
                        views[2]
                    }
                }
                case 5: HorVStack(axis: verticalWhenTall, spacing: spacing) {
                    views[0]
                    if geometry.isTall {
                        HStack(spacing: spacing) {
                            views[1]
                            views[2]
                        }
                        HStack(spacing: spacing) {
                            views[3]
                            views[4]

                        }
                    } else {
                        VStack(spacing: spacing) {
                            views[1]
                            views[3]
                        }
                        VStack(spacing: spacing) {
                            views[2]
                            views[4]
                        }
                    }
                }
                //            case 6:
                //                if geometry.isTall {
                //                    VStack {
                //                        HStack {
                //                            views[0]
                //                            views[1]
                //                        }
                //                        HStack {
                //                            views[2]
                //                            views[3]
                //                        }
                //                        HStack {
                //                            views[4]
                //                            views[5]
                //                        }
                //                    }
                //                } else {
                //                    VStack {
                //                        HStack {
                //                            views[0]
                //                            views[1]
                //                            views[2]
                //                        }
                //                        HStack {
                //                            views[3]
                //                            views[4]
                //                            views[5]
                //                        }
                //                    }
                //                }
                default:
                    let c = computeColumn(with: geometry)
                    VStack(spacing: spacing) {
                        ForEach(0...(c.y - 1), id: \.self) { y in
                            HStack(spacing: spacing) {
                                ForEach(0...(c.x - 1), id: \.self) { x in
                                    let index = (y * c.x) + x
                                    if index < views.count {
                                        views[index]
                                    }
                                }
                            }
                        }
                    }

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

struct HorVGrid<Content: View>: View {
    let axis: Axis
    let spacing: CGFloat?
    let content: () -> Content
    let columns: [GridItem]

    init(axis: Axis = .horizontal,
         columns: [GridItem],
         spacing: CGFloat? = nil,
         @ViewBuilder content: @escaping () -> Content) {

        self.axis = axis
        self.spacing = spacing
        self.columns = columns
        self.content = content
    }

    var body: some View {
        Group {
            if axis == .vertical {
                LazyVGrid(columns: columns, spacing: spacing, content: content)
            } else {
                LazyHGrid(rows: columns, spacing: spacing, content: content)
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
