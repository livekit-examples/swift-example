/*
 * Copyright 2024 LiveKit
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

// This class contains the logic to control behavior of the whole app.
final class RoomContext: ObservableObject {
    let jsonEncoder = JSONEncoder()
    let jsonDecoder = JSONDecoder()

    private let store: ValueStore<Preferences>

    // Used to show connection error dialog
    // private var didClose: Bool = false
    @Published var shouldShowDisconnectReason: Bool = false
    public var latestError: LiveKitError?

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

    @Published var isE2eeEnabled: Bool = false {
        didSet {
            store.value.isE2eeEnabled = isE2eeEnabled
            // room.set(isE2eeEnabled: isE2eeEnabled)
        }
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
        isE2eeEnabled = store.value.isE2eeEnabled
        e2eeKey = store.value.e2eeKey
        simulcast = store.value.simulcast
        adaptiveStream = store.value.adaptiveStream
        dynacast = store.value.dynacast
        reportStats = store.value.reportStats
        autoSubscribe = store.value.autoSubscribe

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
            isE2eeEnabled = entry.e2ee
            e2eeKey = entry.e2eeKey
        }

        let connectOptions = ConnectOptions(
            autoSubscribe: autoSubscribe
        )

        var e2eeOptions: E2EEOptions? = nil
        if isE2eeEnabled {
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
                simulcast: simulcast
            ),
            adaptiveStream: true,
            dynacast: true,
            // isE2eeEnabled: isE2eeEnabled,
            e2eeOptions: e2eeOptions,
            reportRemoteTrackStatistics: true
        )

        let connectTask = Task.detached { [weak self] in
            guard let self else { return }
            try await self.room.connect(url: self.url,
                                        token: self.token,
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

        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let json = try self.jsonEncoder.encode(roomMessage)
                try await self.room.localParticipant.publish(data: json)
            } catch {
                print("Failed to encode data \(error)")
            }
        }
    }

    #if os(macOS)
        weak var screenShareTrack: LocalTrackPublication?

        @available(macOS 12.3, *)
        func setScreenShareMacOS(isEnabled: Bool, screenShareSource: MacOSScreenCaptureSource? = nil) async throws {
            if isEnabled, let screenShareSource {
                let track = LocalVideoTrack.createMacOSScreenShareTrack(source: screenShareSource)
                let options = VideoPublishOptions(preferredCodec: VideoCodec.h264)
                screenShareTrack = try await room.localParticipant.publish(videoTrack: track, options: options)
            }

            if !isEnabled, let screenShareTrack {
                try await room.localParticipant.unpublish(publication: screenShareTrack)
            }
        }
    #endif
}

extension RoomContext: RoomDelegate {
    func room(_: Room, track publication: TrackPublication, didUpdateE2EEState e2eeState: E2EEState) {
        print("Did update e2eeState = [\(String(describing: e2eeState))] for publication \(publication.sid)")
    }

    func room(_ room: Room, didUpdateConnectionState connectionState: ConnectionState, from oldValue: ConnectionState) {
        print("Did update connectionState \(oldValue) -> \(connectionState)")

        if case .disconnected = connectionState,
           let error = room.disconnectError,
           error.type != .cancelled
        {
            latestError = room.disconnectError

            Task.detached { @MainActor [weak self] in
                guard let self else { return }
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

    func room(_: Room, participantDidDisconnect participant: RemoteParticipant) {
        Task.detached { @MainActor [weak self] in
            guard let self else { return }
            if let focusParticipant = self.focusParticipant, focusParticipant.identity == participant.identity {
                self.focusParticipant = nil
            }
        }
    }

    func room(_: Room, participant _: RemoteParticipant?, didReceiveData data: Data, forTopic _: String) {
        do {
            let roomMessage = try jsonDecoder.decode(ExampleRoomMessage.self, from: data)
            // Update UI from main queue
            Task.detached { @MainActor [weak self] in
                guard let self else { return }

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
