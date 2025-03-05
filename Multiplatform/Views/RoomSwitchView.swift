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

    #if os(visionOS)
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    #endif

    var shouldShowRoomView: Bool {
        room.connectionState == .connected || room.connectionState == .reconnecting
    }

    func computeTitle() -> String {
        if shouldShowRoomView {
            var elements: [String] = []
            if let roomName = room.name {
                elements.append(roomName)
            }
            if let localParticipantName = room.localParticipant.name {
                elements.append(localParticipantName)
            }
            if let localParticipantIdentity = room.localParticipant.identity {
                elements.append(String(describing: localParticipantIdentity))
            }
            return elements.joined(separator: " ")
        }

        return "LiveKit"
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if shouldShowRoomView {
                RoomView()
            } else {
                ConnectView()
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle(computeTitle())
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
