import Foundation
import CoreGraphics
import SwiftUI
import LiveKit
import Promises

#if os(macOS)

class ScreenShareSourcePickerCtrl: ObservableObject {

    @Published var tracks = [LocalVideoTrack]()
    @Published var mode: ScreenShareSourcePickerView.Mode = .display {
        didSet {
            guard oldValue != mode else { return }
            restartTracks()
        }
    }

    private func restartTracks() {

        // stop all
        let stopAllPromise = all(tracks.map { $0.stop() })
        let sourcesPromise = MacOSScreenCapturer.sources(for: (mode == .display ? .display : .window))

        stopAllPromise.then { _ in
            sourcesPromise
        }.then { sources in
            sources.map {
                LocalVideoTrack.createMacOSScreenShareTrack(source: $0)
            }
        }.then { tracks -> Promise<[LocalVideoTrack]> in
            all(tracks.map({ $0.start() })).then { _ in tracks }
        }.then(on: .main) { tracks in
            self.tracks = tracks
        }.catch { error in
            assert(false, "error: \(error)")
        }
    }

    init() {
        restartTracks()
    }

    deinit {

        print("\(type(of: self)) deinit")

        _ = all(tracks.map { $0.stop() }).catch { error in
            // should not happen
            assert(false, "error: \(error)")
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
