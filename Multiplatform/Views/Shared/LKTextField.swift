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

import SwiftUI

struct LKTextField: View {
    enum `Type` {
        case `default`
        case URL
        case ascii
        case secret
    }

    let title: String
    @Binding var text: String
    var type: Type = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 10.0) {
            Text(title)
                .fontWeight(.bold)

            Group {
                if type == .secret {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .textFieldStyle(.plain)
            .disableAutocorrection(true)
            .padding()
            .overlay(RoundedRectangle(cornerRadius: 10.0)
                .strokeBorder(Color.white.opacity(0.3),
                              style: StrokeStyle(lineWidth: 1.0)))
            #if os(iOS)
                .autocapitalization(.none)
                .keyboardType(type.toiOSType())
            #endif

        }.frame(maxWidth: .infinity)
    }
}

#if os(iOS)
extension LKTextField.`Type` {
    func toiOSType() -> UIKeyboardType {
        switch self {
        case .URL: .URL
        case .ascii: .asciiCapable
        default: .default
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
