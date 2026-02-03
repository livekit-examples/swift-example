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

struct MessagesPanel: View {
    @EnvironmentObject var roomCtx: RoomContext
    @EnvironmentObject var room: Room

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { scrollView in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .center, spacing: 0) {
                        ForEach(roomCtx.messages) {
                            messageView($0)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 7)
                }
                .onAppear(perform: {
                    scrollToBottom(scrollView)
                })
                .onChange(of: roomCtx.messages, perform: { _ in
                    scrollToBottom(scrollView)
                })
                .frame(
                    minWidth: 0,
                    maxWidth: .infinity,
                    minHeight: 0,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
            }
            HStack(spacing: 0) {
                TextField("Enter message", text: $roomCtx.textFieldString)
                    .textFieldStyle(PlainTextFieldStyle())
                    .disableAutocorrection(true)

                Button {
                    roomCtx.sendMessage()
                } label: {
                    Image(systemSymbol: .paperplaneFill)
                        .foregroundColor(roomCtx.textFieldString.isEmpty ? nil : Color.lkRed)
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color.lkGray2)
        }
    }

    func messageView(_ message: ExampleRoomMessage) -> some View {
        let isMe = message.senderSid == room.localParticipant.sid

        return HStack {
            if isMe {
                Spacer()
            }

            Text(message.text)
                .padding(8)
                .background(isMe ? Color.lkRed : Color.lkGray3)
                .foregroundColor(Color.white)
                .cornerRadius(18)

            if !isMe {
                Spacer()
            }
        }.padding(.vertical, 5)
            .padding(.horizontal, 10)
    }

    func scrollToBottom(_ scrollView: ScrollViewProxy) {
        guard let last = roomCtx.messages.last else { return }
        withAnimation {
            scrollView.scrollTo(last.id)
        }
    }
}
