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

import LiveKit
import SwiftUI

/// Sheet presented from the RoomView toolbar. Lets the user pick a destination
/// participant, type a method name and payload, send an RPC, and view the response.
struct RpcTesterView: View {
    let room: Room
    let onClose: () -> Void

    @State private var identity: String = ""
    @State private var method: String = "test"
    @State private var payload: String = ""
    @State private var isSending: Bool = false
    @State private var result: RpcOutcome?

    private enum RpcOutcome {
        case success(payload: String, latency: TimeInterval)
        case failure(error: Error)
    }

    private var remoteIdentities: [String] {
        room.remoteParticipants.keys
            .map(\.stringValue)
            .sorted()
    }

    private var canSend: Bool {
        !identity.isEmpty && !method.isEmpty && !isSending
    }

    var body: some View {
        NavigationStack {
            Form {
                destinationSection
                methodSection
                payloadSection
                sendSection
                if let result {
                    resultSection(for: result)
                }
            }
            .navigationTitle("RPC Tester")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                }
            }
        }
        .onAppear {
            if identity.isEmpty, let first = remoteIdentities.first {
                identity = first
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var destinationSection: some View {
        Section {
            TextField("", text: $identity)
                .textFieldStyle(.automatic)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            if !remoteIdentities.isEmpty {
                Menu {
                    ForEach(remoteIdentities, id: \.self) { id in
                        Button(id) { identity = id }
                    }
                } label: {
                    Label("Pick from room (\(remoteIdentities.count))", systemImage: "person.2")
                        .font(.caption)
                }
            } else {
                Text("No remote participants in room")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Destination participant")
        }
    }

    @ViewBuilder
    private var methodSection: some View {
        Section("Method") {
            TextField("", text: $method)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
        }
    }

    @ViewBuilder
    private var payloadSection: some View {
        Section {
            TextEditor(text: $payload)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 120, maxHeight: 240)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            HStack {
                Text("\(payload.utf8.count) bytes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Menu("Quick fill") {
                    Button("1 KB of 'a'") { payload = String(repeating: "a", count: 1_000) }
                    Button("20 KB of 'a' (forces v2)") { payload = String(repeating: "a", count: 20_000) }
                    Button("Clear") { payload = "" }
                }
                .font(.caption)
            }
        } header: {
            Text("Payload")
        }
    }

    @ViewBuilder
    private var sendSection: some View {
        Section {
            Button(action: sendRpc) {
                HStack {
                    if isSending {
                        ProgressView()
                            #if os(macOS)
                            .scaleEffect(0.6)
                            #endif
                        Text("Sending…")
                    } else {
                        Image(systemName: "paperplane.fill")
                        Text("Send")
                    }
                    Spacer()
                }
            }
            .disabled(!canSend)
        }
    }

    @ViewBuilder
    private func resultSection(for outcome: RpcOutcome) -> some View {
        switch outcome {
        case let .success(responsePayload, latency):
            Section {
                HStack {
                    Label("\(responsePayload.utf8.count) bytes", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Spacer()
                    Text(String(format: "%.0f ms", latency * 1000))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                ScrollView {
                    Text(responsePayload.isEmpty ? "(empty response)" : responsePayload)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(.vertical, 4)
                }
                .frame(minHeight: 80, maxHeight: 240)
            } header: {
                Text("Response")
            }
        case let .failure(error):
            Section {
                Label(failureTitle(for: error), systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                if let rpc = error as? RpcError {
                    Text("Code \(rpc.code) — \(rpc.message)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if !rpc.data.isEmpty {
                        Text(rpc.data)
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(String(describing: error))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Error")
            }
        }
    }

    private func failureTitle(for error: Error) -> String {
        if let rpc = error as? RpcError { return rpc.message }
        return "RPC failed"
    }

    // MARK: - Send

    private func sendRpc() {
        let destination = Participant.Identity(from: identity)
        let methodName = method
        let body = payload
        result = nil
        isSending = true
        let started = Date()

        Task { @MainActor in
            do {
                let response = try await room.localParticipant.performRpc(
                    destinationIdentity: destination,
                    method: methodName,
                    payload: body
                )
                result = .success(payload: response, latency: Date().timeIntervalSince(started))
            } catch {
                result = .failure(error: error)
            }
            isSending = false
        }
    }
}
