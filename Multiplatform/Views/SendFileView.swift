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

import SwiftUI

struct SendFileView: View {

    @EnvironmentObject var roomCtx: RoomContext
    @State private var isPickerPresented = false

    var body: some View {
        HStack {
            Group {
                if let selectedFile = roomCtx.selectedFile {
                    FileInfo(url: selectedFile)
                } else {
                    Text("Tap to select a file…")
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.gray.opacity(0.15))
            )
            .padding(8)
            .onTapGesture { isPickerPresented.toggle() }
            
            SendButton {
                roomCtx.sendFile()
            }
            .disabled(roomCtx.selectedFile == nil || roomCtx.isFileSending)
        }
        .fileImporter(isPresented: $isPickerPresented, allowedContentTypes: [.data]) { result in
            guard let url = try? result.get() else { return }
            roomCtx.selectedFile = url
        }
    }
}

private struct FileInfo: View {

    let url: URL
    @State private var fileSize: Int?

    var body: some View {
        HStack(spacing: 10) {
            Text(url.lastPathComponent)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            if let fileSize, #available(iOS 15.0, *) {
                Text(fileSize.formatted(.byteCount(style: .file)))
            }
        }
        .task(id: url) {
            guard let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]) else { return }
            fileSize = resourceValues.fileSize
        }
    }
}

private struct SendButton: View {

    let action: @MainActor () -> Void
  
    var body: some View {
        Button("Send", systemImage: "paperplane.fill", action: action)
            .buttonStyle(Style())
    }
    private struct Style: ButtonStyle {
        
        @Environment(\.isEnabled) private var isEnabled
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .labelStyle(.iconOnly)
                .padding(6)
                .background(Circle().fill(.lkBlue))
                .opacity(isEnabled ? 1 : 0.5)
                .foregroundColor(.white)
        }
    }
}

#Preview {
    SendFileView()
        .padding()
        .frame(width: 300)
}
