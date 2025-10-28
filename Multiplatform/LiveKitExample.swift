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

import KeychainAccess
import LiveKit
import SwiftUI

@MainActor let sync = ValueStore<Preferences>(store: Keychain(service: "io.livekit.example.SwiftSDK.1"),
                                              key: "preferences",
                                              default: Preferences())

@main
struct LiveKitExample: App {
    @StateObject var appCtx = AppContext(store: sync)
    @State var roomID = 0

    #if os(visionOS)
    @Environment(\.openWindow) var openWindow
    #endif

    var body: some Scene {
        WindowGroup {
            RoomContextView(roomID: $roomID)
                .environmentObject(appCtx)
                .id(roomID)
        }
        #if !os(tvOS)
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
        #endif
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        #endif

        #if os(visionOS)
        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
        }
        .immersionStyle(selection: .constant(.full), in: .full)
        #endif
    }

    init() {
        LiveKitSDK.setLogLevel(.debug)
    }
}
