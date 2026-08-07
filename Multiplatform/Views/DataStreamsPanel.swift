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
import SFSafeSymbols
import SwiftUI

// TextEditor is unavailable on tvOS.
#if !os(tvOS)
struct DataStreamsPanel: View {
    @EnvironmentObject var room: Room
    @EnvironmentObject var dataStreamsCtx: DataStreamsContext

    private var remoteIdentities: [String] {
        // Participant.Identity is not Comparable, so sort the string values.
        room.remoteParticipants.keys.map(\.stringValue).sorted()
    }

    /// Presents "All participants" whenever the selected participant is gone.
    private var destination: Binding<String> {
        Binding(
            get: {
                let current = dataStreamsCtx.sendDestination
                return remoteIdentities.contains(current) ? current : ""
            },
            set: { dataStreamsCtx.sendDestination = $0 }
        )
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                sendSection
                Divider()
                subscriptionsSection
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Send

    private var sendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Send")
                .font(.headline)

            Picker("Kind", selection: $dataStreamsCtx.sendKind) {
                ForEach(DataStreamKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            fieldLabel("Topic")
            plainField("Topic", text: $dataStreamsCtx.sendTopic)

            fieldLabel("To")
            Picker("To", selection: destination) {
                Text("All participants").tag("")
                ForEach(remoteIdentities, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            fieldLabel("Content")
            HStack(spacing: 8) {
                Button("Hello world") { dataStreamsCtx.applyHelloWorldPreset() }
                Button("20k random") { dataStreamsCtx.applyRandomPreset() }
            }
            .buttonStyle(.bordered)
            .font(.caption)

            TextEditor(text: $dataStreamsCtx.sendContent)
                .font(.system(size: 11, design: .monospaced))
                .frame(height: 90)
                .scrollContentBackground(.hidden)
                .padding(4)
                .overlay(RoundedRectangle(cornerRadius: 10.0)
                    .strokeBorder(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.0)))

            Text("\(dataStreamsCtx.sendContent.count) characters")
                .font(.caption2)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                LKButton(title: "Send") { dataStreamsCtx.send() }
                    .opacity(dataStreamsCtx.canSend ? 1 : 0.5)
                    .disabled(!dataStreamsCtx.canSend)

                if dataStreamsCtx.isSending {
                    ProgressView().controlSize(.small)
                }
            }

            sendStatusView
        }
    }

    @ViewBuilder
    private var sendStatusView: some View {
        switch dataStreamsCtx.sendStatus {
        case .idle:
            EmptyView()
        case .sending:
            Text("Sending…")
                .font(.caption)
                .foregroundColor(.secondary)
        case let .sent(streamID, byteCount):
            Text("Sent \(String(streamID.prefix(8)))… (\(dataStreamByteCountLabel(byteCount)))")
                .font(.caption)
                .foregroundColor(.green)
        case let .failed(message):
            Text("Error: \(message)")
                .font(.caption)
                .foregroundColor(Color.lkRed)
        }
    }

    // MARK: - Subscriptions

    private var subscriptionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Subscriptions (\(dataStreamsCtx.subscriptions.count))")
                .font(.headline)

            Picker("Kind", selection: $dataStreamsCtx.newSubscriptionKind) {
                ForEach(DataStreamKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(spacing: 8) {
                plainField("Topic", text: $dataStreamsCtx.newSubscriptionTopic)
                Button("Add") { dataStreamsCtx.addSubscription() }
                    .buttonStyle(.bordered)
                    .disabled(!canAddSubscription)
            }

            if dataStreamsCtx.subscriptions.isEmpty {
                Text("No subscriptions yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(dataStreamsCtx.subscriptions) { subscription in
                    SubscriptionCard(subscription: subscription)
                }
            }
        }
    }

    private var canAddSubscription: Bool {
        dataStreamsCtx.canAddSubscription(topic: dataStreamsCtx.newSubscriptionTopic,
                                          kind: dataStreamsCtx.newSubscriptionKind)
    }

    // MARK: - Shared bits

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.bold)
    }

    private func plainField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .disableAutocorrection(true)
            .padding(8)
            .overlay(RoundedRectangle(cornerRadius: 10.0)
                .strokeBorder(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.0)))
        #if os(iOS)
            .autocapitalization(.none)
            .keyboardType(.asciiCapable)
        #endif
    }
}

private struct SubscriptionCard: View {
    @EnvironmentObject var dataStreamsCtx: DataStreamsContext

    let subscription: DataStreamSubscription

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(subscription.topic)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                Text(subscription.kind.badge)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    dataStreamsCtx.removeSubscription(subscription.id)
                } label: {
                    Image(systemSymbol: .xmarkCircleFill)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }

            if let registrationError = subscription.registrationError {
                Text(registrationError)
                    .font(.caption2)
                    .foregroundColor(Color.lkRed)
            }

            Text("Received (\(subscription.totalReceived))")
                .font(.caption)
                .foregroundColor(.secondary)

            if subscription.payloads.isEmpty {
                Text("Nothing received yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(subscription.payloads) { payload in
                            PayloadRow(payload: payload, subscriptionID: subscription.id)
                            Divider()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 170)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lkGray2)
        .cornerRadius(8)
    }
}

private struct PayloadRow: View {
    @EnvironmentObject var dataStreamsCtx: DataStreamsContext

    let payload: ReceivedPayload
    let subscriptionID: DataStreamSubscriptionKey

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("#\(payload.sequence) · \(payload.sender) · \(dataStreamByteCountLabel(payload.byteCount)) · \(dataStreamTimeLabel(payload.receivedAt))")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Text(bodyText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(bodyColor)
                .lineLimit(payload.isExpanded ? nil : 1)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            dataStreamsCtx.toggleExpansion(payloadID: payload.id, in: subscriptionID)
        }
    }

    private var bodyText: String {
        switch payload.body {
        case let .text(text): text
        case let .hex(hex): hex
        case let .failure(message): "<error: \(message)>"
        }
    }

    private var bodyColor: Color {
        if case .failure = payload.body { return Color.lkRed }
        return .primary
    }
}
#endif
