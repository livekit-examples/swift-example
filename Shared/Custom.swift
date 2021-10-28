import SwiftUI

struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}

struct LKButton: View {

    let title: String
    let action: () -> Void

    var body: some View {
        //
        Button(action: action, label: {

            VStack {
//                ActivityIndicator(isAnimating: true)
//                if busy {
//                    ProgressView()
//                }

            Text(title)
                .fontWeight(.bold)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
//                .background(Color.accentColor)
                .cornerRadius(10)
            }
        })
    }
}

