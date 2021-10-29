import SwiftUI
import LiveKit

#if !os(macOS)
import UIKit
public typealias NativeViewRepresentable = UIViewRepresentable
#else
// macOS
import AppKit
public typealias NativeViewRepresentable = NSViewRepresentable
#endif

/// A ``VideoView`` that can be used in SwiftUI.
/// Supports both iOS and macOS.
struct SwiftUIVideoView: NativeViewRepresentable {
    /// Pass a ``VideoTrack`` of a ``Participant``.
    let track: VideoTrack

    #if !os(macOS)
    // iOS

    func makeUIView(context: Context) -> VideoView {
        let view = VideoView()
        view.track = track
        return view
    }

    func updateUIView(_ videoView: VideoView, context: Context) {
        videoView.track = track
    }

    static func dismantleUIView(_ videoView: VideoView, coordinator: ()) {
        videoView.track = nil
    }
    #else
    // macOS

    func makeNSView(context: Context) -> VideoView {
        let view = VideoView()
        view.track = track
        return view
    }

    func updateNSView(_ videoView: VideoView, context: Context) {
        videoView.track = track
    }

    static func dismantleNSView(_ videoView: VideoView, coordinator: ()) {
        videoView.track = nil
    }

    #endif
}
