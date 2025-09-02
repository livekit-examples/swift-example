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

#if !os(tvOS)
struct AudioMixerView: View {
    @EnvironmentObject var appCtx: AppContext
    @EnvironmentObject var roomCtx: RoomContext
    @StateObject private var sineWaveGenerator = SineWaveGenerator()
    @State private var isManualMode: Bool = false
    @State private var isMicEnabled: Bool = false
    @State private var isPublishingAudioBuffer: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Audio Mixer")
                .font(.headline)

            // Volume Controls
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Mic Volume")
                    Spacer()
                    Slider(value: $appCtx.micVolume, in: 0.0 ... 1.0)
                        .frame(width: 150)
                }
                HStack {
                    Text("App Volume")
                    Spacer()
                    Slider(value: $appCtx.appVolume, in: 0.0 ... 1.0)
                        .frame(width: 150)
                }
            }

            Divider()

            // Manual Mode Toggle
            HStack {
                Toggle("Manual Rendering Mode", isOn: $isManualMode)
                    .onChange(of: isManualMode) { newValue in
                        Task {
                            do {
                                try AudioManager.shared.setManualRenderingMode(newValue)
                                if newValue {
                                    print("Manual rendering mode enabled - no device access")
                                } else {
                                    print("Manual rendering mode disabled - device access restored")
                                }
                            } catch {
                                errorMessage = "Failed to set manual mode: \(error.localizedDescription)"
                            }
                        }
                    }
            }

            Divider()

            // Microphone Control
            HStack {
                Button(action: toggleMicrophone) {
                    Text(isMicEnabled ? "Disable Microphone" : "Enable Microphone")
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(isMicEnabled ? Color.red : Color.blue)
                        .cornerRadius(8)
                }
                .disabled(roomCtx.room.connectionState != .connected)
            }

            Divider()

            // Audio Buffer Controls
            VStack(alignment: .leading, spacing: 12) {
                Text("Audio Buffer Capture")
                    .font(.subheadline)
                    .fontWeight(.medium)

                // Sine Wave Generator Controls
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Frequency: \(Int(sineWaveGenerator.frequency)) Hz")
                        Spacer()
                        Slider(value: $sineWaveGenerator.frequency, in: 200 ... 2000)
                            .frame(width: 150)
                    }

                    HStack {
                        Text("Amplitude: \(String(format: "%.2f", sineWaveGenerator.amplitude))")
                        Spacer()
                        Slider(value: $sineWaveGenerator.amplitude, in: 0.0 ... 1.0)
                            .frame(width: 150)
                    }

                    HStack {
                        Button(action: {
                            if sineWaveGenerator.isGenerating {
                                sineWaveGenerator.stopGenerating()
                            } else {
                                sineWaveGenerator.startGenerating()
                            }
                        }) {
                            Text(sineWaveGenerator.isGenerating ? "Stop Sine Wave" : "Start Sine Wave")
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(sineWaveGenerator.isGenerating ? Color.red : Color.green)
                                .cornerRadius(8)
                        }
                        .disabled(roomCtx.room.connectionState != .connected)

                        Spacer()

                        Button(action: toggleAudioBufferPublishing) {
                            Text(isPublishingAudioBuffer ? "Stop Publishing Audio Buffer" : "Start Publishing Audio Buffer")
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isPublishingAudioBuffer ? Color.red : Color.orange)
                                .cornerRadius(8)
                        }
                        .disabled(roomCtx.room.connectionState != .connected)
                    }
                }
            }

            // Error Message
            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.top, 8)
            }

            // Instructions
            VStack(alignment: .leading, spacing: 4) {
                Text("Instructions:")
                    .font(.caption)
                    .fontWeight(.medium)

                Text("• Enable microphone to capture both mic and app audio")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("• Use manual mode to publish only app audio (no mic access)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("• Adjust volumes to control mic vs app audio levels")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
        .padding()
        .onAppear {
            // Initialize manual mode state
            isManualMode = AudioManager.shared.isManualRenderingMode
        }
    }

    private func toggleMicrophone() {
        Task {
            do {
                try await roomCtx.room.localParticipant.setMicrophone(enabled: !isMicEnabled)
                isMicEnabled.toggle()
            } catch {
                errorMessage = "Failed to toggle microphone: \(error.localizedDescription)"
            }
        }
    }

    private func toggleAudioBufferPublishing() {
        if isPublishingAudioBuffer {
            // Stop publishing
            isPublishingAudioBuffer = false
            sineWaveGenerator.stopGenerating()
        } else {
            // Start publishing
            isPublishingAudioBuffer = true

            // If not in manual mode, enable microphone to capture both mic and app audio
            if !isManualMode, !isMicEnabled {
                Task {
                    do {
                        try await roomCtx.room.localParticipant.setMicrophone(enabled: true)
                        isMicEnabled = true
                    } catch {
                        errorMessage = "Failed to enable microphone: \(error.localizedDescription)"
                        return
                    }
                }
            }

            // Start generating sine wave
            sineWaveGenerator.startGenerating()
        }
    }
}
#endif
