/*
 * Copyright 2023 LiveKit
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

import Foundation
import LiveKit
import SwiftUI

struct AudioProcessorOptionsView: View {
    typealias OnNSEnabled = (_ enabled: Bool) -> Void

    @State private var enabled: Bool
    private let roomCtx: RoomContext
    private let onEnabled: OnNSEnabled

    init(roomCtx: RoomContext, _ onEnabled: @escaping OnNSEnabled) {
        self.roomCtx = roomCtx
        self.onEnabled = onEnabled
        self.enabled = !LiveKit.AudioManager.shared.bypassForCapturePostProcessing
    }

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Text("Audio Processor")
                .fontWeight(.bold)
            Text("name: \(roomCtx.room.audioProcessorOptions?.getCapturePostProcessor()?.getName() ?? "")")
            
            Toggle(isOn: $enabled, label: {
                Text("Toggle")
            }).onChange(of: enabled) { newValue in
                LiveKit.AudioManager.shared.bypassForCapturePostProcessing = !newValue
            }
            .keyboardShortcut(.defaultAction)
        }
    }
}
