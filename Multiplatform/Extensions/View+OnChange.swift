/*
 * Copyright 2026 LiveKit
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

#if !os(tvOS) && !os(visionOS)
extension View {
    @available(iOS, introduced: 14.0, obsoleted: 17.0)
    @available(macOS, introduced: 11.0, obsoleted: 14.0)
    func onChange(of value: some Equatable, _ action: @escaping () -> Void) -> some View {
        onChange(of: value) { _ in action() }
    }
}
#endif
