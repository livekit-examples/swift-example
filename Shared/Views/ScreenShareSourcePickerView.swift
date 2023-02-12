import Foundation
import CoreGraphics
import SwiftUI
import LiveKit

#if os(macOS)

class ScreenShareSourcePickerCtrl: ObservableObject {

    @Published var tracks = [LocalVideoTrack]()
    @Published var mode: ScreenShareSourcePickerView.Mode = .display {
        didSet {
            guard oldValue != mode else { return }
            Task {
                await restartTracks()
            }
        }
    }

    private func restartTracks() async {

        Task {
            // stop in parallel
            await withThrowingTaskGroup(of: Void.self) { group in
                for track in tracks {
                    group.addTask {
                        try await track.stop()
                    }
                }
            }

            let sources = try await MacOSScreenCapturer.sources(for: (mode == .display ? .display : .window))
            let _newTracks = sources.map { LocalVideoTrack.createMacOSScreenShareTrack(source: $0) }

            Task { @MainActor in
                self.tracks = _newTracks
            }

            // start in parallel
            await withThrowingTaskGroup(of: Void.self) { group in
                for track in _newTracks {
                    group.addTask {
                        try await track.start()
                    }
                }
            }
        }
    }

    init() {
        Task {
            await restartTracks()
        }
    }

    deinit {

        print("\(type(of: self)) deinit")

        // copy
        let _tracks = tracks

        Task {
            // stop in parallel
            await withThrowingTaskGroup(of: Void.self) { group in
                for track in _tracks {
                    group.addTask {
                        try await track.stop()
                    }
                }
            }
        }
    }
}

typealias OnPickScreenShareSource = (MacOSScreenCaptureSource) -> Void

struct ScreenShareSourcePickerView: View {

    public enum Mode {
        case display
        case window
    }

    @ObservedObject var ctrl = ScreenShareSourcePickerCtrl()

    let onPickScreenShareSource: OnPickScreenShareSource?

    private var columns = [
        GridItem(.fixed(250)),
        GridItem(.fixed(250))
    ]

    init(onPickScreenShareSource: OnPickScreenShareSource? = nil) {
        self.onPickScreenShareSource = onPickScreenShareSource
    }

    var body: some View {

        VStack {
            Picker("", selection: $ctrl.mode) {
                Text("Entire Screen").tag(ScreenShareSourcePickerView.Mode.display)
                Text("Application Window").tag(ScreenShareSourcePickerView.Mode.window)
            }
            .pickerStyle(SegmentedPickerStyle())

            ScrollView(.vertical, showsIndicators: true) {
                LazyVGrid(columns: columns,
                          alignment: .center,
                          spacing: 10) {

                    ForEach(ctrl.tracks) { track in
                        ZStack {
                            SwiftUIVideoView(track, layoutMode: .fit)
                                .aspectRatio(1, contentMode: .fit)
                                .onTapGesture {
                                    guard let capturer = track.capturer as? MacOSScreenCapturer,
                                          let source = capturer.captureSource else { return }
                                    onPickScreenShareSource?(source)
                                }

                            if let capturer = track.capturer as? MacOSScreenCapturer,
                               let source = capturer.captureSource as? MacOSWindow,
                               let appName = source.owningApplication?.applicationName {
                                Text(appName)
                            }
                        }
                    }
                }
            }
            .frame(minHeight: 350)
        }
    }
}

#endif
