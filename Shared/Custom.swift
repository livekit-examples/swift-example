/*
 * Copyright 2024 LiveKit
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

import SwiftUI

extension Color {
    static let lkRed = Color("lkRed")
    static let lkDarkRed = Color("lkDarkRed")
    static let lkGray1 = Color("lkGray1")
    static let lkGray2 = Color("lkGray2")
    static let lkGray3 = Color("lkGray3")
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
               })
               .background(Color.lkRed)
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
        override open var focusRingType: NSFocusRingType {
            get { .none }
            set {}
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
