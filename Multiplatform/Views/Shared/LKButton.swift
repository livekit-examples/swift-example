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
