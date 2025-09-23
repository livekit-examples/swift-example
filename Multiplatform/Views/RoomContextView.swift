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

// Attaches RoomContext and Room to the environment
struct RoomContextView: View {
    @EnvironmentObject var appCtx: AppContext
    @StateObject var roomCtx = RoomContext(store: sync)

    var body: some View {
        RoomSwitchView()
            .environmentObject(roomCtx)
            .environmentObject(roomCtx.room)
            .foregroundColor(Color.white)
            .onDisappear {
                print("\(String(describing: type(of: self))) onDisappear")
                Task {
                    await roomCtx.disconnect()
                }
            }
            .onOpenURL(perform: { url in
                guard let urlComponent = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
                guard let host = url.host else { return }

                let secureValue = urlComponent.queryItems?.first(where: { $0.name == "secure" })?.value?.lowercased()
                let secure = ["true", "1"].contains { $0 == secureValue }

                let tokenValue = urlComponent.queryItems?.first(where: { $0.name == "token" })?.value ?? ""

                let e2ee = ["true", "1"].contains { $0 == secureValue }
                let e2eeKey = urlComponent.queryItems?.first(where: { $0.name == "e2eeKey" })?.value ?? ""

                var builder = URLComponents()
                builder.scheme = secure ? "wss" : "ws"
                builder.host = host
                builder.port = url.port

                guard let builtUrl = builder.url?.absoluteString else { return }

                print("built URL: \(builtUrl), token: \(tokenValue)")

                Task { @MainActor in
                    roomCtx.url = builtUrl
                    roomCtx.token = tokenValue
                    roomCtx.isE2eeEnabled = e2ee
                    roomCtx.e2eeKey = e2eeKey
                    if !roomCtx.token.isEmpty {
                        let room = try await roomCtx.connect()
                        appCtx.connectionHistory.update(room: room, e2ee: e2ee, e2eeKey: e2eeKey)
                    }
                }
            })
    }
}
