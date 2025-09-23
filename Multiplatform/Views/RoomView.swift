/*
 * Copyright 2025 LiveKit
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import LiveKit
import SFSafeSymbols
import SwiftUI

#if !os(macOS) && !os(tvOS)
let adaptiveMin = 170.0
let toolbarPlacement: ToolbarItemPlacement = .bottomBar
#else
let adaptiveMin = 300.0
let toolbarPlacement: ToolbarItemPlacement = .primaryAction
#endif

extension ToolbarItemPlacement: @unchecked Swift.Sendable {}

#if os(macOS)
// keeps weak reference to NSWindow
@MainActor
final class WindowAccess: ObservableObject {
    private weak var window: NSWindow?

    deinit {
        // reset changed properties
        DispatchQueue.main.async { [weak window] in
            window?.level = .normal
        }
    }

    @Published var pinned: Bool = false {
        didSet {
            guard oldValue != pinned else { return }
            level = pinned ? .floating : .normal
        }
    }

    private var level: NSWindow.Level {
        get { window?.level ?? .normal }
        set {
            Task { @MainActor in
                window?.level = newValue
                objectWillChange.send()
            }
        }
    }

    func set(window: NSWindow?) {
        self.window = window
        Task { @MainActor in
            objectWillChange.send()
        }
    }
}
#endif

struct RoomView: View {
    @EnvironmentObject var appCtx: AppContext
    @EnvironmentObject var roomCtx: RoomContext
    @EnvironmentObject var room: Room

    @State var isCameraPublishingBusy = false
    @State var isMicrophonePublishingBusy = false
    @State var isScreenSharePublishingBusy = false
    @State var isARCameraPublishingBusy = false

    @State private var screenPickerPresented = false
    @State private var publishOptionsPickerPresented = false
    @State private var audioMixerOptionsPresented = false

    @State private var cameraPublishOptions = VideoPublishOptions()

    #if os(macOS)
    @ObservedObject private var windowAccess = WindowAccess()
    #endif

    @State private var showConnectionTime = true
    @State private var canSwitchCameraPosition = false

    func messageView(_ message: ExampleRoomMessage) -> some View {
        let isMe = message.senderSid == room.localParticipant.sid

        return HStack {
            if isMe {
                Spacer()
            }

            //            VStack(alignment: isMe ? .trailing : .leading) {
            //                Text(message.identity)
            Text(message.text)
                .padding(8)
                .background(isMe ? Color.lkRed : Color.lkGray3)
                .foregroundColor(Color.white)
                .cornerRadius(18)
            //            }
            if !isMe {
                Spacer()
            }
        }.padding(.vertical, 5)
            .padding(.horizontal, 10)
    }

    func scrollToBottom(_ scrollView: ScrollViewProxy) {
        guard let last = roomCtx.messages.last else { return }
        withAnimation {
            scrollView.scrollTo(last.id)
        }
    }

    func messagesView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            ScrollViewReader { scrollView in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .center, spacing: 0) {
                        ForEach(roomCtx.messages) {
                            messageView($0)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 7)
                }
                .onAppear(perform: {
                    // Scroll to bottom when first showing the messages list
                    scrollToBottom(scrollView)
                })
                .onChange(of: roomCtx.messages, perform: { _ in
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
                TextField("Enter message", text: $roomCtx.textFieldString)
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
                    roomCtx.sendMessage()
                } label: {
                    Image(systemSymbol: .paperplaneFill)
                        .foregroundColor(roomCtx.textFieldString.isEmpty ? nil : Color.lkRed)
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color.lkGray2)
        }
        .background(Color.lkGray1)
        .cornerRadius(8)
        .frame(
            minWidth: 0,
            maxWidth: geometry.isTall ? .infinity : 320
        )
    }

    func sortedParticipants() -> [Participant] {
        room.allParticipants.values.sorted { p1, p2 in
            if p1 is LocalParticipant { return true }
            if p2 is LocalParticipant { return false }
            return (p1.joinedAt ?? Date()) < (p2.joinedAt ?? Date())
        }
    }

    func content(geometry: GeometryProxy) -> some View {
        VStack {
            if showConnectionTime {
                Text("Connected (\([room.serverRegion, room.serverNodeId, "\(String(describing: room.connectStopwatch.total().rounded(to: 2)))s"].compactMap { $0 }.joined(separator: ", ")))")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding()
            }

            if case .connecting = room.connectionState {
                Text("Re-connecting...")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding()
            }

            HorVStack(axis: geometry.isTall ? .vertical : .horizontal, spacing: 5) {
                Group {
                    if let focusParticipant = roomCtx.focusParticipant {
                        ZStack(alignment: .bottomTrailing) {
                            ParticipantView(participant: focusParticipant,
                                            videoViewMode: appCtx.videoViewMode)
                            { _ in
                                roomCtx.focusParticipant = nil
                            }
                            .overlay(RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.lkRed.opacity(0.7), lineWidth: 5.0))
                            Text("SELECTED")
                                .font(.system(size: 10))
                                .fontWeight(.bold)
                                .foregroundColor(Color.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.lkRed.opacity(0.7))
                                .cornerRadius(8)
                                .padding(.vertical, 35)
                                .padding(.horizontal, 10)
                        }

                    } else {
                        // Array([room.allParticipants.values, room.allParticipants.values].joined())
                        ParticipantLayout(sortedParticipants(), spacing: 5) { participant in
                            ParticipantView(participant: participant,
                                            videoViewMode: appCtx.videoViewMode)
                            { participant in
                                roomCtx.focusParticipant = participant
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
                if roomCtx.showMessagesView {
                    messagesView(geometry: geometry)
                }
            }
        }
        .padding(5)
    }

    var body: some View {
        GeometryReader { geometry in
            content(geometry: geometry)
        }
        .toolbar {
            ToolbarItemGroup(placement: toolbarPlacement) {
                // Insufficient space on iOS bar
                #if os(macOS)
                Group {
                    if let name = room.name {
                        Text(name)
                            .fontWeight(.bold)
                    }

                    if let identity = room.localParticipant.identity {
                        Text(String(describing: identity))
                    }

                    Spacer()

                    Picker("Mode", selection: $appCtx.videoViewMode) {
                        Text("Fit").tag(VideoView.LayoutMode.fit)
                        Text("Fill").tag(VideoView.LayoutMode.fill)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                #else
                Spacer()
                #endif

                Group {
                    let isCameraEnabled = room.localParticipant.isCameraEnabled()
                    let isMicrophoneEnabled = room.localParticipant.isMicrophoneEnabled()
                    let isScreenShareEnabled = room.localParticipant.isScreenShareEnabled()

                    Group {
                        #if os(visionOS) && compiler(>=6.0)
                        // Toggle camera enabled
                        Button(action: {
                                   Task {
                                       isARCameraPublishingBusy = true
                                       defer { Task { @MainActor in isARCameraPublishingBusy = false } }
                                       try await roomCtx.setARCamera(isEnabled: true)
                                   }

                               },
                               label: {
                                   Image(systemSymbol: .eyeglasses)
                                       .renderingMode(isCameraEnabled ? .original : .template)
                               })
                               // disable while publishing/un-publishing
                               .disabled(isARCameraPublishingBusy)
                        #endif

                        if isCameraEnabled, canSwitchCameraPosition {
                            Menu {
                                Button("Switch position") {
                                    Task {
                                        isCameraPublishingBusy = true
                                        defer { Task { @MainActor in isCameraPublishingBusy = false } }
                                        if let track = room.localParticipant.firstCameraVideoTrack as? LocalVideoTrack,
                                           let cameraCapturer = track.capturer as? CameraCapturer
                                        {
                                            try await cameraCapturer.switchCameraPosition()
                                        }
                                    }
                                }

                                Button("Disable") {
                                    Task {
                                        isCameraPublishingBusy = true
                                        defer { Task { @MainActor in isCameraPublishingBusy = false } }
                                        try await room.localParticipant.setCamera(enabled: !isCameraEnabled)
                                    }
                                }
                            } label: {
                                Image(systemSymbol: .videoFill)
                                    .renderingMode(.original)
                            }
                            // disable while publishing/un-publishing
                            .disabled(isCameraPublishingBusy)
                        } else {
                            // Toggle camera enabled
                            Button(action: {
                                       if isCameraEnabled {
                                           Task {
                                               isCameraPublishingBusy = true
                                               defer { Task { @MainActor in isCameraPublishingBusy = false } }
                                               try await room.localParticipant.setCamera(enabled: false)
                                           }
                                       } else {
                                           publishOptionsPickerPresented = true
                                       }
                                   },
                                   label: {
                                       Image(systemSymbol: .videoFill)
                                           .renderingMode(isCameraEnabled ? .original : .template)
                                   })
                                   // disable while publishing/un-publishing
                                   .disabled(isCameraPublishingBusy)
                        }
                    }
                    #if !os(tvOS)
                    .popover(isPresented: $publishOptionsPickerPresented) {
                        PublishOptionsView(publishOptions: cameraPublishOptions) { captureOptions, publishOptions in
                            publishOptionsPickerPresented = false
                            isCameraPublishingBusy = true
                            cameraPublishOptions = publishOptions
                            Task {
                                defer { Task { @MainActor in isCameraPublishingBusy = false } }
                                try await room.localParticipant.setCamera(enabled: true,
                                                                          captureOptions: captureOptions,
                                                                          publishOptions: publishOptions)
                            }
                        }
                        .padding()
                    }
                    #endif

                    // Toggle microphone enabled
                    Button(action: {
                               Task {
                                   isMicrophonePublishingBusy = true
                                   defer { Task { @MainActor in isMicrophonePublishingBusy = false } }
                                   let options = AudioCaptureOptions(noiseSuppression: false, highpassFilter: false)
                                   try await room.localParticipant.setMicrophone(enabled: !isMicrophoneEnabled, captureOptions: options)
                               }
                           },
                           label: {
                               Image(systemSymbol: .micFill)
                                   .renderingMode(isMicrophoneEnabled ? .original : .template)
                           })
                           // disable while publishing/un-publishing
                           .disabled(isMicrophonePublishingBusy)

                    Button {
                        audioMixerOptionsPresented = true
                    } label: {
                        Image(systemSymbol: .switch2)
                    }
                    .disabled(!isMicrophoneEnabled)
                    #if !os(tvOS)
                        .popover(isPresented: $audioMixerOptionsPresented) {
                            AudioMixerView()
                                .padding()
                        }
                    #endif

                    #if os(iOS)
                    Button(action: {
                               Task {
                                   isScreenSharePublishingBusy = true
                                   defer { Task { @MainActor in isScreenSharePublishingBusy = false } }
                                   try await room.localParticipant.setScreenShare(enabled: !isScreenShareEnabled)
                               }
                           },
                           label: {
                               Image(systemSymbol: .rectangleFillOnRectangleFill)
                                   .renderingMode(isScreenShareEnabled ? .original : .template)
                           })
                           // disable while publishing/un-publishing
                           .disabled(isScreenSharePublishingBusy)
                    #elseif os(macOS)
                    Button(action: {
                               if #available(macOS 12.3, *) {
                                   if isScreenShareEnabled {
                                       // Turn off screen share
                                       Task {
                                           isScreenSharePublishingBusy = true
                                           defer { Task { @MainActor in isScreenSharePublishingBusy = false } }
                                           try await roomCtx.setScreenShareMacOS(isEnabled: false)
                                       }
                                   } else {
                                       screenPickerPresented = true
                                   }
                               }
                           },
                           label: {
                               Image(systemSymbol: .rectangleFillOnRectangleFill)
                                   .renderingMode(isScreenShareEnabled ? .original : .template)
                                   .foregroundColor(isScreenShareEnabled ? Color.green : Color.white)
                           }).popover(isPresented: $screenPickerPresented) {
                        if #available(macOS 12.3, *) {
                            ScreenShareSourcePickerView { source in
                                Task {
                                    isScreenSharePublishingBusy = true
                                    defer { Task { @MainActor in isScreenSharePublishingBusy = false } }
                                    try await roomCtx.setScreenShareMacOS(isEnabled: true, screenShareSource: source)
                                }
                                screenPickerPresented = false
                            }.padding()
                        }
                    }
                    .disabled(isScreenSharePublishingBusy)
                    #endif

                    // Toggle messages view (chat example)
                    Button(action: {
                               withAnimation {
                                   roomCtx.showMessagesView.toggle()
                               }
                           },
                           label: {
                               Image(systemSymbol: .messageFill)
                                   .renderingMode(roomCtx.showMessagesView ? .original : .template)
                           })
                }

                // Spacer()

                #if os(iOS)
                SwiftUIAudioRoutePickerButton()
                #endif

                Menu {
                    #if os(macOS)
                    Button("New window") {
                        if let url = URL(string: "livekit://") {
                            NSWorkspace.shared.open(url)
                        }
                    }

                    Divider()

                    #endif

                    Toggle("Show info overlay", isOn: $appCtx.showInformationOverlay)

                    Group {
                        Toggle("VideoView visible", isOn: $appCtx.videoViewVisible)
                        Toggle("VideoView flip", isOn: $appCtx.videoViewMirrored)
                        Toggle("VideoView renderMode: .sampleBuffer", isOn: $appCtx.preferSampleBufferRendering)
                        #if os(iOS)
                        Menu("Pinch to zoom") {
                            Toggle("Zoom In", isOn: $appCtx.videoViewPinchToZoomOptions.bind(.zoomIn))
                            Toggle("Zoom Out", isOn: $appCtx.videoViewPinchToZoomOptions.bind(.zoomOut))
                            Toggle("Auto Reset", isOn: $appCtx.videoViewPinchToZoomOptions.bind(.resetOnRelease))
                        }
                        #endif
                        Divider()
                    }

                    Group {
                        Toggle("Background blur", isOn: $roomCtx.isVideoProcessingEnabled)
                    }

                    #if os(macOS)
                    Group {
                        Picker("Output device", selection: $appCtx.outputDevice) {
                            ForEach($appCtx.outputDevices) { device in
                                Text(device.wrappedValue.isDefault ? "Default (\(device.wrappedValue.name))" : "\(device.wrappedValue.name)").tag(device.wrappedValue)
                            }
                        }
                        Picker("Input device", selection: $appCtx.inputDevice) {
                            ForEach($appCtx.inputDevices) { device in
                                Text(device.wrappedValue.isDefault ? "Default (\(device.wrappedValue.name))" : "\(device.wrappedValue.name)").tag(device.wrappedValue)
                            }
                        }
                    }
                    #endif

                    Group {
                        Divider()

                        Button("Unpublish all") {
                            Task { await room.localParticipant.unpublishAll() }
                        }

                        Divider()

                        Menu("Simulate scenario") {
                            Button("Quick reconnect") {
                                Task { try await room.debug_simulate(scenario: .quickReconnect) }
                            }
                            Button("Full reconnect") {
                                Task { try await room.debug_simulate(scenario: .fullReconnect) }
                            }
                            Button("Node failure") {
                                Task { try await room.debug_simulate(scenario: .nodeFailure) }
                            }
                            Button("Server leave") {
                                Task { try await room.debug_simulate(scenario: .serverLeave) }
                            }
                            Button("Migration") {
                                Task { try await room.debug_simulate(scenario: .migration) }
                            }
                            Button("Speaker update") {
                                Task { try await room.debug_simulate(scenario: .speakerUpdate(seconds: 3)) }
                            }
                            Button("Force TCP") {
                                Task { try await room.debug_simulate(scenario: .forceTCP) }
                            }
                            Button("Force TLS") {
                                Task { try await room.debug_simulate(scenario: .forceTLS) }
                            }
                        }
                    }

                    Group {
                        Menu("Track permissions") {
                            Button("Allow all") {
                                Task {
                                    try await room.localParticipant
                                        .setTrackSubscriptionPermissions(allParticipantsAllowed: true)
                                }
                            }
                            Button("Disallow all") {
                                Task {
                                    try await room.localParticipant
                                        .setTrackSubscriptionPermissions(allParticipantsAllowed: false)
                                }
                            }
                        }

                        #if os(iOS) || os(visionOS) || os(tvOS)
                        Toggle("Prefer speaker output", isOn: $appCtx.preferSpeakerOutput)
                        #endif

                        Toggle("Bypass voice processing", isOn: $appCtx.isVoiceProcessingBypassed)

                        Picker("Mic mute mode", selection: $appCtx.micMuteMode) {
                            ForEach([MicrophoneMuteMode.voiceProcessing,
                                     MicrophoneMuteMode.restart,
                                     MicrophoneMuteMode.inputMixer], id: \.self)
                            { mode in
                                Text("Mute: \(mode)").tag(mode)
                            }
                        }

                        Toggle("E2EE enabled", isOn: $roomCtx.isE2eeEnabled)
                    }

                } label: {
                    Image(systemSymbol: .gear)
                        .renderingMode(.original)
                }

                // Disconnect
                Button(action: {
                           Task {
                               await roomCtx.disconnect()
                           }
                       },
                       label: {
                           Image(systemSymbol: .xmarkCircleFill)
                               .renderingMode(.original)
                       })
            }
        }
        // #if os(macOS)
        // .withHostingWindow { self.windowAccess.set(window: $0) }
        // #endif
        .onAppear {
            Task { @MainActor in
                canSwitchCameraPosition = try await CameraCapturer.canSwitchPosition()
            }
            Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
                Task { @MainActor in
                    withAnimation {
                        showConnectionTime = false
                    }
                }
            }
        }
    }
}

struct ParticipantLayout<Content: View>: View {
    let views: [AnyView]
    let spacing: CGFloat

    init<Data: RandomAccessCollection>(
        _ data: Data,
        id: KeyPath<Data.Element, Data.Element> = \.self,
        spacing: CGFloat,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.spacing = spacing
        views = data.map { AnyView(content($0[keyPath: id])) }
    }

    func computeColumn(with geometry: GeometryProxy) -> (x: Int, y: Int) {
        let sqr = Double(views.count).squareRoot()
        let r: [Int] = [Int(sqr.rounded()), Int(sqr.rounded(.up))]
        let c = geometry.isTall ? r : r.reversed()
        return (x: c[0], y: c[1])
    }

    func grid(axis: Axis, geometry: GeometryProxy) -> some View {
        ScrollView([axis == .vertical ? .vertical : .horizontal]) {
            HorVGrid(axis: axis, columns: [GridItem(.flexible())], spacing: spacing) {
                ForEach(0 ..< views.count, id: \.self) { i in
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
                        ForEach(0 ... (c.y - 1), id: \.self) { y in
                            HStack(spacing: spacing) {
                                ForEach(0 ... (c.x - 1), id: \.self) { x in
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
         @ViewBuilder content: @escaping () -> Content)
    {
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
         @ViewBuilder content: @escaping () -> Content)
    {
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
