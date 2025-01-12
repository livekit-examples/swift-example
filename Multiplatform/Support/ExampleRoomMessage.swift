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

struct ExampleRoomMessage: Identifiable, Equatable, Hashable, Codable {
    // Identifiable protocol needs param named id
    var id: String {
        messageId
    }

    // message id
    let messageId: String

    let senderSid: Participant.Sid?
    let senderIdentity: Participant.Identity?
    let text: String

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.messageId == rhs.messageId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(messageId)
    }
}
