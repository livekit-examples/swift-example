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
import LiveKit

// Drives the data streams panel: composing outgoing streams and subscribing to
// incoming ones.
//
// Stream handler registrations are Room-scoped and outlive a session, so they are
// added when the user adds a subscription and removed when the user removes it —
// never on connect or disconnect. That keeps subscriptions working across a
// reconnect and means there is no path that re-registers an already-registered
// topic.
@MainActor
final class DataStreamsContext: ObservableObject {
    private let room: Room

    // Send form
    @Published var sendKind: DataStreamKind = .text
    @Published var sendTopic: String = "demo"
    /// Identity `stringValue` of the target participant; empty means broadcast.
    @Published var sendDestination: String = ""
    @Published var sendContent: String = ""
    @Published var isSending: Bool = false
    @Published var sendStatus: DataStreamSendStatus = .idle

    // Subscribe form
    @Published var newSubscriptionTopic: String = ""
    @Published var newSubscriptionKind: DataStreamKind = .text

    @Published private(set) var subscriptions: [DataStreamSubscription] = []

    /// Serializes register/unregister so that removing and immediately re-adding the
    /// same topic cannot interleave into a `handlerAlreadyRegistered` error.
    private var registrationTask: Task<Void, Never>?

    init(room: Room) {
        self.room = room
    }

    // MARK: - Sending

    var canSend: Bool {
        !isSending && !sendTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func applyHelloWorldPreset() {
        sendContent = "hello world"
    }

    func applyRandomPreset() {
        sendContent = dataStreamRandomString(length: DataStreamLimits.randomPayloadLength)
    }

    func send() {
        let topic = sendTopic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !topic.isEmpty, !isSending else { return }

        // Resolve the destination at send time, falling back to broadcast if the
        // selected participant has since left.
        let destinations: [Participant.Identity]
        if !sendDestination.isEmpty,
           room.remoteParticipants.keys.contains(where: { $0.stringValue == sendDestination })
        {
            destinations = [Participant.Identity(from: sendDestination)]
        } else {
            destinations = []
        }

        let kind = sendKind
        let content = sendContent
        isSending = true
        sendStatus = .sending

        Task { [weak self] in
            guard let self else { return }
            do {
                let streamID: String
                let byteCount: Int

                switch kind {
                case .text:
                    // Convenience initializer; omitting `compress:` disambiguates it
                    // from the designated one.
                    let options = StreamTextOptions(topic: topic, destinationIdentities: destinations)
                    let info = try await room.localParticipant.sendText(content, options: options)
                    streamID = info.id
                    byteCount = content.utf8.count

                case .bytes:
                    // There is no in-memory byte send, so stage the payload in a
                    // temporary file and send that.
                    let data = Data(content.utf8)
                    let directory = try Self.writeTemporaryFile(data: data)
                    defer { try? FileManager.default.removeItem(at: directory) }
                    let options = StreamByteOptions(topic: topic, destinationIdentities: destinations)
                    let info = try await room.localParticipant.sendFile(directory.appendingPathComponent(Self.temporaryFileName),
                                                                        options: options)
                    streamID = info.id
                    byteCount = data.count
                }

                sendStatus = .sent(streamID: streamID, byteCount: byteCount)
            } catch {
                sendStatus = .failed(Self.describe(error))
            }
            isSending = false
        }
    }

    private static let temporaryFileName = "test.txt"

    /// Stages an outgoing byte payload on disk. `sendFile` fills in the stream's
    /// name, MIME type and total size from the file itself. Returns the enclosing
    /// directory so the caller can delete the whole thing afterwards.
    private static func writeTemporaryFile(data: Data) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lk-data-streams-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent(temporaryFileName))
        return directory
    }

    // MARK: - Subscriptions

    func canAddSubscription(topic: String, kind: DataStreamKind) -> Bool {
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let key = DataStreamSubscriptionKey(topic: trimmed, kind: kind)
        return !subscriptions.contains { $0.id == key }
    }

    func addSubscription() {
        let topic = newSubscriptionTopic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canAddSubscription(topic: topic, kind: newSubscriptionKind) else { return }

        let key = DataStreamSubscriptionKey(topic: topic, kind: newSubscriptionKind)
        // Insert synchronously so a double tap cannot race past the duplicate check.
        subscriptions.append(DataStreamSubscription(id: key))
        newSubscriptionTopic = ""

        enqueueRegistration { [weak self] in
            guard let self else { return }
            do {
                switch key.kind {
                case .text:
                    try await room.registerTextStreamHandler(for: key.topic,
                                                             onNewStream: makeTextHandler(for: key))
                case .bytes:
                    try await room.registerByteStreamHandler(for: key.topic,
                                                             onNewStream: makeByteHandler(for: key))
                }
            } catch {
                // Keep the row so the failure stays visible and removable.
                if let index = subscriptions.firstIndex(where: { $0.id == key }) {
                    subscriptions[index].registrationError = Self.describe(error)
                }
            }
        }
    }

    func removeSubscription(_ key: DataStreamSubscriptionKey) {
        subscriptions.removeAll { $0.id == key }

        enqueueRegistration { [weak self] in
            guard let self else { return }
            switch key.kind {
            case .text: await room.unregisterTextStreamHandler(for: key.topic)
            case .bytes: await room.unregisterByteStreamHandler(for: key.topic)
            }
        }
    }

    func toggleExpansion(payloadID: UUID, in key: DataStreamSubscriptionKey) {
        guard let subscriptionIndex = subscriptions.firstIndex(where: { $0.id == key }),
              let payloadIndex = subscriptions[subscriptionIndex].payloads.firstIndex(where: { $0.id == payloadID })
        else { return }
        subscriptions[subscriptionIndex].payloads[payloadIndex].isExpanded.toggle()
    }

    /// Keeps the subscription list — registrations survive a reconnect — but drops
    /// everything tied to the finished session.
    func roomDidDisconnect() {
        for index in subscriptions.indices {
            subscriptions[index].payloads.removeAll()
            subscriptions[index].totalReceived = 0
        }
        sendDestination = ""
        sendStatus = .idle
        isSending = false
    }

    private func enqueueRegistration(_ operation: @escaping @MainActor () async -> Void) {
        let previous = registrationTask
        registrationTask = Task { @MainActor in
            await previous?.value
            await operation()
        }
    }

    // MARK: - Receiving

    // The SDK invokes handlers on a detached task and discards anything they throw,
    // so each one catches internally and surfaces the error as a payload row. The
    // read, decode and truncation all happen off the main actor; only the finished
    // value crosses over.

    private func makeTextHandler(for key: DataStreamSubscriptionKey) -> TextStreamHandler {
        { [weak self] reader, identity in
            guard let self else { return }
            let streamID = reader.info.id
            do {
                let text = try await reader.readAll()
                let body = ReceivedPayload.Body.text(dataStreamCapped(text))
                await record(body,
                             sender: identity.stringValue,
                             byteCount: text.utf8.count,
                             streamID: streamID,
                             for: key)
            } catch {
                await record(.failure(Self.describe(error)),
                             sender: identity.stringValue,
                             byteCount: 0,
                             streamID: streamID,
                             for: key)
            }
        }
    }

    private func makeByteHandler(for key: DataStreamSubscriptionKey) -> ByteStreamHandler {
        { [weak self] reader, identity in
            guard let self else { return }
            let streamID = reader.info.id
            do {
                let data = try await reader.readAll()
                let body: ReceivedPayload.Body = if let text = String(data: data, encoding: .utf8) {
                    .text(dataStreamCapped(text))
                } else {
                    .hex(dataStreamHexDump(data))
                }
                await record(body,
                             sender: identity.stringValue,
                             byteCount: data.count,
                             streamID: streamID,
                             for: key)
            } catch {
                await record(.failure(Self.describe(error)),
                             sender: identity.stringValue,
                             byteCount: 0,
                             streamID: streamID,
                             for: key)
            }
        }
    }

    private func record(_ body: ReceivedPayload.Body,
                        sender: String,
                        byteCount: Int,
                        streamID: String,
                        for key: DataStreamSubscriptionKey)
    {
        // A stream can land after its subscription was removed; dropping it is correct.
        guard let index = subscriptions.firstIndex(where: { $0.id == key }) else { return }

        subscriptions[index].totalReceived += 1
        subscriptions[index].payloads.append(
            ReceivedPayload(id: UUID(),
                            sequence: subscriptions[index].totalReceived,
                            sender: sender,
                            receivedAt: Date(),
                            byteCount: byteCount,
                            streamID: streamID,
                            body: body)
        )

        let overflow = subscriptions[index].payloads.count - DataStreamLimits.retainedPayloads
        if overflow > 0 {
            subscriptions[index].payloads.removeFirst(overflow)
        }
    }

    static func describe(_ error: Error) -> String {
        if let error = error as? StreamError { return String(describing: error) }
        if let error = error as? LiveKitError { return error.errorDescription ?? "\(error)" }
        return error.localizedDescription
    }
}
