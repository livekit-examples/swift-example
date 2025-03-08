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

struct FileTransferView: View {
    var body: some View {
        VStack(spacing: 8) {
            SendFile()
            IncomingFilesList()
        }
    }
}

private struct SendFile: View {

    @EnvironmentObject var roomCtx: RoomContext

    var body: some View {
        HStack(spacing: 4) {
            FileWell(selectedFile: $roomCtx.selectedFile)
                .disabled(roomCtx.isFileSending)
            Spacer()
            SendButton(isBusy: roomCtx.isFileSending) {
                roomCtx.sendFile()
            }
            .disabled(roomCtx.selectedFile == nil || roomCtx.isFileSending)
        }
    }
}

private struct FileWell: View {
    
    @Binding var selectedFile: URL?
    
    @Environment(\.isEnabled) private var isEnabled
    @State private var isPickerPresented = false
    
    var body: some View {
        HStack {
            if let selectedFile {
                SelectedFileInfo(url: selectedFile)
                    .padding(.leading, 8)
                Spacer()
            } else {
                Text("Tap to select a file…")
                    .italic()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.35))
        )

        .onTapGesture {
            guard isEnabled else { return  }
            isPickerPresented.toggle()
        }
        .fileImporter(isPresented: $isPickerPresented, allowedContentTypes: [.data]) { result in
            guard let url = try? result.get() else { return }
            selectedFile = url
        }
    }
}

private struct IncomingFilesList: View {

    @EnvironmentObject var roomCtx: RoomContext

    var body: some View {
        List {
            Section("Incoming Files") {
                ForEach(roomCtx.incomingFiles) { file in
                    IncomingFileCell(file: file)
                        .contextMenu {
                            #if os(iOS)
                            if let url = file.fileURL, #available(iOS 16.0, *)  {
                                ShareLink(item: url)
                            }
                            #elseif os(macOS)
                            Button("Save File", systemImage: "square.and.arrow.down") {
                                guard let url = file.fileURL else { return }
                                saveFile(url)
                            }
                            .disabled(file.fileURL == nil)
                            #endif
                            Button("Remove", systemImage: "trash", role: .destructive) {
                                withAnimation { roomCtx.removeIncomingFile(id: file.id) }
                            }
                        }
                }
            }
        }
        .frame(minHeight: 300)
        .listStyle(.inset)
    }
    
    #if os(macOS)
    private func saveFile(_ fileURL: URL) {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = fileURL.lastPathComponent
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false

        let response = savePanel.runModal()
        guard savePanel.runModal() == .OK, let destinationURL = savePanel.url else {
            print("File not saved: \(response)")
            return
        }
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: fileURL, to: destinationURL)
        } catch {
            print("Error moving file: \(error.localizedDescription)")
        }
    }
    #endif
}

private struct IncomingFileCell: View {
    
    let file: RoomContext.IncomingFile
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(file.fileName)
                    .font(.headline)
                Text("From \(file.senderIdentity)")
                    .font(.caption)
            }
            .lineLimit(1)

            Spacer()
            switch file.phase {
            case .transferring:
                ProgressView()
                #if os(macOS)
                .controlSize(.small)
                #endif
            case .failed(let error):
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.multicolor)
                    .help("Error: \(error.localizedDescription)")
            case .received(_):
                Image(systemName: "checkmark.circle.fill")
            }
        }
    }
}

private struct SelectedFileInfo: View {
    let url: URL
    @State private var fileSize: Int?

    var body: some View {
        HStack {
            Text(url.lastPathComponent)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            Text(fileSize?.formatted(.byteCount(style: .file)) ?? "—")
                .font(.caption)
        }
        .task(id: url) {
            guard let resourceValues = try? url.resourceValues(
                forKeys: [.fileSizeKey]
            ) else { return }
            
            fileSize = resourceValues.fileSize
        }
    }
}

private struct SendButton: View {
    let isBusy: Bool
    let action: @MainActor () -> Void

    @Environment(\.isEnabled) private var isEnabled
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.lkBlue)
                .frame(width: 50, height: 50)
            if isBusy {
                ProgressView()
                #if os(macOS)
                .controlSize(.small)
                #endif
            } else {
                Image(systemName: "document.badge.arrow.up.fill")
            }
        }
        .opacity(isEnabled ? 1 : 0.5)
        .onTapGesture {
            if isEnabled { action() }
        }
    }
}
