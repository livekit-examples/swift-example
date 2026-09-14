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

import Foundation

// Value types backing the data streams panel. These are deliberately free of any
// actor isolation so stream handlers can build them off the main actor and hand
// the finished value across in a single hop.

enum DataStreamKind: String, CaseIterable, Identifiable, Hashable, Sendable {
    case text
    case bytes

    var id: String { rawValue }
    var title: String { self == .text ? "Text" : "Bytes" }
    var badge: String { self == .text ? "[text]" : "[bytes]" }
}

/// Identifies a subscription. The SDK keeps separate registries for text and byte
/// handlers, so the same topic may legally have one subscription of each kind.
struct DataStreamSubscriptionKey: Hashable, Sendable {
    let topic: String
    let kind: DataStreamKind
}

struct ReceivedPayload: Identifiable, Equatable, Sendable {
    enum Body: Equatable, Sendable {
        case text(String) // already length-capped
        case hex(String) // pre-rendered hex dump, already capped
        case failure(String) // the reader threw; message for display
    }

    let id: UUID
    let sequence: Int // 1-based, monotonic per subscription
    let sender: String
    let receivedAt: Date
    let byteCount: Int // true size, before truncation
    let streamID: String
    let body: Body
    var isExpanded: Bool = false
}

struct DataStreamSubscription: Identifiable, Sendable {
    let id: DataStreamSubscriptionKey
    var payloads: [ReceivedPayload] = []
    /// Monotonic total; unlike `payloads.count` this is not reduced by the retention cap.
    var totalReceived: Int = 0
    var registrationError: String?

    var topic: String { id.topic }
    var kind: DataStreamKind { id.kind }
}

enum DataStreamSendStatus: Equatable, Sendable {
    case idle
    case sending
    case sent(streamID: String, byteCount: Int)
    case failed(String)
}

enum DataStreamLimits {
    static let retainedPayloads = 100
    static let storedBodyCharacters = 4096
    static let hexDumpBytes = 512
    static let randomPayloadLength = 20000
}

// MARK: - Formatting helpers

private let hexAlphabet = Array("0123456789abcdef")

func dataStreamHexDump(_ data: Data, maxBytes: Int = DataStreamLimits.hexDumpBytes) -> String {
    let shown = data.prefix(maxBytes)
    var out = ""
    out.reserveCapacity(shown.count * 3)
    for (offset, byte) in shown.enumerated() {
        if offset > 0 { out.append(" ") }
        out.append(hexAlphabet[Int(byte >> 4)])
        out.append(hexAlphabet[Int(byte & 0x0F)])
    }
    if data.count > maxBytes {
        out += " … (+\(data.count - maxBytes) more bytes)"
    }
    return out
}

func dataStreamCapped(_ text: String, max: Int = DataStreamLimits.storedBodyCharacters) -> String {
    guard text.count > max else { return text }
    return String(text.prefix(max)) + " … (+\(text.count - max) more characters)"
}

func dataStreamRandomString(length: Int) -> String {
    let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".utf8)
    var bytes = [UInt8]()
    bytes.reserveCapacity(length)
    for _ in 0 ..< length {
        bytes.append(alphabet.randomElement()!)
    }
    return String(decoding: bytes, as: UTF8.self)
}

func dataStreamByteCountLabel(_ count: Int) -> String {
    if count < 1024 { return "\(count) B" }
    return String(format: "%.1f kB", Double(count) / 1024.0)
}

private let dataStreamTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    return formatter
}()

func dataStreamTimeLabel(_ date: Date) -> String {
    dataStreamTimeFormatter.string(from: date)
}
