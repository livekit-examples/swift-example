import Foundation
import CoreGraphics
import SwiftUI
import LiveKit
import Promises

#if os(macOS)

class ScreenShareSourcePickerCtrl: ObservableObject {

    private var allTracks = [LocalVideoTrack]()

    @Published var visibleTracks = [LocalVideoTrack]()
    @Published var mode: ScreenShareSourcePickerView.Mode = .display {
        didSet {
            guard oldValue != mode else { return }
            recomputeVisibleTracks()
        }
    }

    private func recomputeVisibleTracks() {

        let tracks = self.allTracks.filter {
            guard let capturer = $0.capturer as? MacOSScreenCapturer else { return false }
            if case .display = capturer.source, case .display = self.mode {
                return true
            } else if case .window = capturer.source, case .window = self.mode {
                return true
            }
            return false
        }

        DispatchQueue.main.async {
            self.visibleTracks = tracks
        }
    }

    init() {
        print("ScreenPickerCtrl.init()")

        // Create tracks for all sources
        self.allTracks = MacOSScreenCapturer.sources().map {
            LocalVideoTrack.createMacOSScreenShareTrack(source: $0)
        }

        // Start all tracks
        let displayStartPromises = self.allTracks.map { $0.start() }
        all(displayStartPromises).then { _ in
            self.recomputeVisibleTracks()
        }
    }

    deinit {
        print("ScreenPickerCtrl.deinit")
        _ = all(self.allTracks.map { $0.stop() })
    }
}

extension LocalVideoTrack: Identifiable {
    public var id: ObjectIdentifier {
        return ObjectIdentifier(self)
    }
}

typealias OnPickScreenShareSource = (ScreenShareSource) -> Void

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

                    ForEach(ctrl.visibleTracks) { track in
                        SwiftUIVideoView(track, layoutMode: .fit)
                            .aspectRatio(1, contentMode: .fit)
                            .onTapGesture {
                                guard let capturer = track.capturer as? MacOSScreenCapturer else { return }
                                onPickScreenShareSource?(capturer.source)
                            }
                    }
                }
            }
            .frame(minHeight: 350)
        }
    }
}

#endif
