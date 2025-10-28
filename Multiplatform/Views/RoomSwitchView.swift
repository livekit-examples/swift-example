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

import LiveKit
import SwiftUI

struct RoomSwitchView: View {
    @EnvironmentObject var appCtx: AppContext
    @EnvironmentObject var roomCtx: RoomContext
    @EnvironmentObject var room: Room
    @Binding var roomID: Int

    #if os(visionOS)
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    #endif

    var shouldShowRoomView: Bool {
        room.connectionState == .connected || room.connectionState == .reconnecting
    }

    private var navigatonTitle: String {
        guard shouldShowRoomView else { return "LiveKit" }
        return [
            room.name,
            room.localParticipant.name,
            room.localParticipant.identity.map(\.stringValue),
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if shouldShowRoomView {
                RoomView()
            } else {
                ConnectView(roomID: $roomID)
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle(navigatonTitle)
        .onChange(of: shouldShowRoomView) { newValue in
            #if os(visionOS)
            Task {
                if newValue {
                    await openImmersiveSpace(id: "ImmersiveSpace")
                } else {
                    await dismissImmersiveSpace()
                }
            }
            #endif
        }
    }
}
