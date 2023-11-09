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

import LiveKit
import SwiftUI
import WebRTC

// This class contains the logic to control behavior of the whole app.
final class RoomContext: ObservableObject {
    let jsonEncoder = JSONEncoder()
    let jsonDecoder = JSONDecoder()

    private let store: ValueStore<Preferences>

    // Used to show connection error dialog
    // private var didClose: Bool = false
    @Published var shouldShowDisconnectReason: Bool = false
    public var latestError: DisconnectReason?

    public let room = Room()

    @Published var url: String = "" {
        didSet { store.value.url = url }
    }

    @Published var token: String = "" {
        didSet { store.value.token = token }
    }

    @Published var e2eeKey: String = "" {
        didSet { store.value.e2eeKey = e2eeKey }
    }

    @Published var e2ee: Bool = false {
        didSet { store.value.e2ee = e2ee }
    }

    // RoomOptions
    @Published var simulcast: Bool = true {
        didSet { store.value.simulcast = simulcast }
    }

    @Published var adaptiveStream: Bool = false {
        didSet { store.value.adaptiveStream = adaptiveStream }
    }

    @Published var dynacast: Bool = false {
        didSet { store.value.dynacast = dynacast }
    }

    @Published var reportStats: Bool = false {
        didSet { store.value.reportStats = reportStats }
    }

    // ConnectOptions
    @Published var autoSubscribe: Bool = true {
        didSet { store.value.autoSubscribe = autoSubscribe }
    }

    @Published var publish: Bool = false {
        didSet { store.value.publishMode = publish }
    }

    @Published var focusParticipant: Participant?

    @Published var showMessagesView: Bool = false
    @Published var messages: [ExampleRoomMessage] = []

    @Published var textFieldString: String = ""

    var _connectTask: Task<Void, Error>?

    public init(store: ValueStore<Preferences>) {
        self.store = store
        room.add(delegate: self)

        url = store.value.url
        token = store.value.token
        e2ee = store.value.e2ee
        e2eeKey = store.value.e2eeKey
        simulcast = store.value.simulcast
        adaptiveStream = store.value.adaptiveStream
        dynacast = store.value.dynacast
        reportStats = store.value.reportStats
        autoSubscribe = store.value.autoSubscribe
        publish = store.value.publishMode

        #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = true
        #endif
    }

    deinit {
        #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = false
        #endif
        print("RoomContext.deinit")
    }

    func cancelConnect() {
        _connectTask?.cancel()
    }

    @MainActor
    func connect(entry: ConnectionHistory? = nil) async throws -> Room {
        if let entry {
            url = entry.url
            token = entry.token
            e2ee = entry.e2ee
            e2eeKey = entry.e2eeKey
        }

        let connectOptions = ConnectOptions(
            autoSubscribe: !publish && autoSubscribe, // don't autosubscribe if publish mode
            publishOnlyMode: publish ? "publish_\(UUID().uuidString)" : nil
        )

        var e2eeOptions: E2EEOptions?
        if e2ee {
            let keyProvider = BaseKeyProvider(isSharedKey: true)
            keyProvider.setKey(key: e2eeKey)
            e2eeOptions = E2EEOptions(keyProvider: keyProvider)
        }

        let roomOptions = RoomOptions(
            defaultCameraCaptureOptions: CameraCaptureOptions(
                dimensions: .h1080_169
            ),
            defaultScreenShareCaptureOptions: ScreenShareCaptureOptions(
                dimensions: .h1080_169,
                useBroadcastExtension: true
            ),
            defaultVideoPublishOptions: VideoPublishOptions(
                simulcast: publish ? false : simulcast
            ),
            adaptiveStream: adaptiveStream,
            dynacast: dynacast,
            e2eeOptions: e2eeOptions
        )

        let connectTask = Task {
            try await room.connect(url: url,
                                   token: token,
                                   connectOptions: connectOptions,
                                   roomOptions: roomOptions)
        }

        _connectTask = connectTask
        try await connectTask.value

        return room
    }

    func disconnect() async {
        await room.disconnect()
    }

    func sendMessage() {
        // Make sure the message is not empty
        guard !textFieldString.isEmpty else { return }

        let roomMessage = ExampleRoomMessage(messageId: UUID().uuidString,
                                             senderSid: room.localParticipant.sid,
                                             senderIdentity: room.localParticipant.identity,
                                             text: textFieldString)
        textFieldString = ""
        messages.append(roomMessage)

        Task {
            do {
                let json = try jsonEncoder.encode(roomMessage)
                try await room.localParticipant.publish(data: json)
            } catch {
                print("Failed to encode data \(error)")
            }
        }
    }

    #if os(macOS)
        weak var screenShareTrack: LocalTrackPublication?

        @available(macOS 12.3, *)
        func setScreenShareMacOS(enabled: Bool, screenShareSource: MacOSScreenCaptureSource? = nil) async throws {
            if enabled, let screenShareSource {
                let track = LocalVideoTrack.createMacOSScreenShareTrack(source: screenShareSource)
                screenShareTrack = try await room.localParticipant.publish(videoTrack: track)
            }

            if !enabled, let screenShareTrack {
                try await room.localParticipant.unpublish(publication: screenShareTrack)
            }
        }
    #endif
}

extension RoomContext: RoomDelegate {
    func room(_: Room, publication: TrackPublication, didUpdateE2EEState e2eeState: E2EEState) {
        print("Did update e2eeState = [\(e2eeState.toString())] for publication \(publication.sid)")
    }

    func room(_: Room, didUpdate connectionState: ConnectionState, oldValue: ConnectionState) {
        print("Did update connectionState \(oldValue) -> \(connectionState)")

        if case let .disconnected(reason) = connectionState, reason != .user {
            latestError = reason
            DispatchQueue.main.async {
                self.shouldShowDisconnectReason = true
                // Reset state
                self.focusParticipant = nil
                self.showMessagesView = false
                self.textFieldString = ""
                self.messages.removeAll()
                // self.objectWillChange.send()
            }
        }
    }

    func room(_: Room, participantDidLeave participant: RemoteParticipant) {
        DispatchQueue.main.async {
            // self.participants.removeValue(forKey: participant.sid)
            if let focusParticipant = self.focusParticipant,
               focusParticipant.sid == participant.sid
            {
                self.focusParticipant = nil
            }
        }
    }

    func room(_: Room, participant _: RemoteParticipant?, didReceiveData data: Data, topic _: String) {
        do {
            let roomMessage = try jsonDecoder.decode(ExampleRoomMessage.self, from: data)
            // Update UI from main queue
            DispatchQueue.main.async {
                withAnimation {
                    // Add messages to the @Published messages property
                    // which will trigger the UI to update
                    self.messages.append(roomMessage)
                    // Show the messages view when new messages arrive
                    self.showMessagesView = true
                }
            }

        } catch {
            print("Failed to decode data \(error)")
        }
    }
}
