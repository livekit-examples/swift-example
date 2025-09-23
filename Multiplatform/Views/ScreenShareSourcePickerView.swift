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

import CoreGraphics
import Foundation
import LiveKit
import SwiftUI

#if os(macOS)

@MainActor
@available(macOS 12.3, *)
final class ScreenShareSourcePickerCtrl: ObservableObject {
    @Published var tracks = [LocalVideoTrack]()
    @Published var mode: ScreenShareSourcePickerView.Mode = .display {
        didSet {
            guard oldValue != mode else { return }
            Task { [weak self] in
                guard let self else { return }
                try await restartTracks()
            }
        }
    }

    init() {
        Task {
            try await restartTracks()
        }
    }

    nonisolated func stopTracks() async throws {
        // stop in parallel
        await withThrowingTaskGroup(of: Void.self) { group in
            for track in await tracks {
                group.addTask {
                    try await track.stop()
                }
            }
        }
    }

    private nonisolated func restartTracks() async throws {
        try await stopTracks()

        let sources = try await MacOSScreenCapturer.sources(for: mode == .display ? .display : .window)
        let options = ScreenShareCaptureOptions(dimensions: .h360_43, fps: 5)
        let _newTracks = sources.map { LocalVideoTrack.createMacOSScreenShareTrack(source: $0, options: options) }

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

typealias OnPickScreenShareSource = (MacOSScreenCaptureSource) -> Void

@available(macOS 12.3, *)
struct ScreenShareSourcePickerView: View {
    enum Mode: Sendable {
        case display
        case window
    }

    @ObservedObject var ctrl = ScreenShareSourcePickerCtrl()

    let onPickScreenShareSource: OnPickScreenShareSource?

    private var columns = [
        GridItem(.fixed(250)),
        GridItem(.fixed(250)),
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
                          spacing: 10)
                {
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
                               let appName = source.owningApplication?.applicationName
                            {
                                Text(appName)
                                    .shadow(color: .black, radius: 1)
                            }
                        }
                    }
                }
            }
            .frame(minHeight: 350)
        }
        .onDisappear {
            Task {
                try? await ctrl.stopTracks()
            }
        }
    }
}

#endif
