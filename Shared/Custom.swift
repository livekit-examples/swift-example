import SwiftUI

extension Color {
    static let lkBlue = Color("LKBlue")
    static let lkDarkBlue = Color("LKDarkBlue")
}

struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}

// Default button style for this example
struct LKButton: View {

    let title: String
    let action: () -> Void

    var body: some View {

        Button(action: action,
               label: {
                Text(title.uppercased())
                    .fontWeight(.bold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
               }
        )   .background(Color.blue)
        .cornerRadius(8)
    }
}

#if os(iOS)
extension LKTextField.`Type` {
    func toiOSType() -> UIKeyboardType {
        switch self {
        case .default: return .default
        case .URL: return .URL
        case .ascii: return .asciiCapable
        }
    }
}
#endif

#if os(macOS)
// Avoid showing focus border around textfield for macOS
extension NSTextField {
    open override var focusRingType: NSFocusRingType {
        get { .none }
        set { }
    }
}
#endif

struct LKTextField: View {

    enum `Type` {
        case `default`
        case URL
        case ascii
    }

    let title: String
    @Binding var text: String
    var type: Type = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 10.0) {
            Text(title)
                .fontWeight(.bold)

            TextField("", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .disableAutocorrection(true)
                // TODO: add iOS unique view modifiers
                // #if os(iOS)
                // .autocapitalization(.none)
                // .keyboardType(type.toiOSType())
                // #endif
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 10.0)
                            .strokeBorder(Color.white.opacity(0.3),
                                          style: StrokeStyle(lineWidth: 1.0)))

        }.frame(maxWidth: .infinity)
    }
}
