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

#if !os(tvOS)
struct AudioMixerView: View {
    @EnvironmentObject var appCtx: AppContext

    var body: some View {
        Text("Mic audio mixer")
        HStack {
            Text("Mic")
            Slider(value: $appCtx.micVolume, in: 0.0 ... 1.0)
        }
        HStack {
            Text("App")
            Slider(value: $appCtx.appVolume, in: 0.0 ... 1.0)
        }
    }
}
#endif
