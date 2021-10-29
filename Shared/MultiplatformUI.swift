// import SwiftUI
//
// #if !os(macOS)
// import UIKit
// typealias ViewRepresentable = UIViewRepresentable
// #else
// typealias ViewRepresentable = NSViewRepresentable
// #endif
//
// struct ActivityIndicator: ViewRepresentable {
//
//    var isAnimating: Bool
//
// #if !os(macOS)
//    func makeUIView(context: Context) -> UIActivityIndicatorView {
//        UIActivityIndicatorView(style: style)
//    }
//
//    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
//        isAnimating ? uiView.startAnimating() : uiView.stopAnimating()
//    }
// #else
//
//    func makeNSView(context: Context) -> some NSView {
//        NSProgressIndicator()
//    }
//
//    func updateNSView(_ nsView: NSViewType, context: Context) {
//        //
//    }
// #endif
//
// }
