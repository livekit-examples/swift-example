import Foundation
import SwiftUI
import LiveKit
import SFSafeSymbols

struct ConnectView: View {

    @EnvironmentObject var appCtx: AppContext
    @EnvironmentObject var roomCtx: RoomContext

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .center, spacing: 40.0) {

                    VStack(spacing: 10) {
                        Image("logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 30)
                            .padding(.bottom, 10)
                        Text("SDK Version \(LiveKit.version)")
                            .opacity(0.5)
                        Text("Example App Version \(Bundle.main.appVersionLong) (\(Bundle.main.appBuild))")
                            .opacity(0.5)
                    }

                    VStack(spacing: 15) {
                        LKTextField(title: "Server URL", text: $roomCtx.url, type: .URL)
                        LKTextField(title: "Token", text: $roomCtx.token, type: .ascii)
                        LKTextField(title: "E2EE Key", text: $roomCtx.e2eeKey, type: .ascii)

                        HStack {
                            Menu {
                                Toggle(isOn: $roomCtx.autoSubscribe) {
                                    Text("Auto-Subscribe")
                                }
                                Toggle(isOn: $roomCtx.publish) {
                                    Text("Publish only mode")
                                }
                                Toggle(isOn: $roomCtx.e2ee) {
                                    Text("Enable E2EE")
                                }
                            } label: {
                                Image(systemSymbol: .boltFill)
                                    .renderingMode(.original)
                                Text("Connect Options")
                            }
                            #if os(macOS)
                            .menuStyle(BorderlessButtonMenuStyle(showsMenuIndicator: true))
                            #elseif os(iOS)
                            .menuStyle(BorderlessButtonMenuStyle())
                            #endif
                            .fixedSize()

                            Menu {
                                Toggle(isOn: $roomCtx.simulcast) {
                                    Text("Simulcast")
                                }
                                Toggle(isOn: $roomCtx.adaptiveStream) {
                                    Text("AdaptiveStream")
                                }
                                Toggle(isOn: $roomCtx.dynacast) {
                                    Text("Dynacast")
                                }
                                Toggle(isOn: $roomCtx.reportStats) {
                                    Text("Report stats")
                                }
                            } label: {
                                Image(systemSymbol: .gear)
                                    .renderingMode(.original)
                                Text("Room Options")
                            }
                            #if os(macOS)
                            .menuStyle(BorderlessButtonMenuStyle(showsMenuIndicator: true))
                            #elseif os(iOS)
                            .menuStyle(BorderlessButtonMenuStyle())
                            #endif
                            .fixedSize()
                        }
                    }.frame(maxWidth: 350)

                    if case .connecting = roomCtx.room.room.connectionState {
                        ProgressView()
                    } else {
                        HStack(alignment: .center) {
                            Spacer()

                            LKButton(title: "Connect") {
                                Task {
                                    let room = try await roomCtx.connect()
                                    appCtx.connectionHistory.update(room: room, e2ee: roomCtx.e2ee, e2eeKey: roomCtx.e2eeKey)
                                }
                            }

                            if !appCtx.connectionHistory.isEmpty {
                                Menu {
                                    ForEach(appCtx.connectionHistory.sortedByUpdated) { entry in
                                        Button {
                                            Task {
                                                let room = try await roomCtx.connect(entry: entry)
                                                appCtx.connectionHistory.update(room: room, e2ee: roomCtx.e2ee, e2eeKey: roomCtx.e2eeKey)
                                            }
                                        } label: {
                                            Image(systemSymbol: .boltFill)
                                                .renderingMode(.original)
                                            Text([entry.roomName,
                                                  entry.participantIdentity,
                                                  entry.url].compactMap { $0 }.joined(separator: " "))
                                        }
                                    }

                                    Divider()

                                    Button {
                                        appCtx.connectionHistory.removeAll()
                                    } label: {
                                        Image(systemSymbol: .xmarkCircleFill)
                                            .renderingMode(.original)
                                        Text("Clear history")
                                    }

                                } label: {
                                    Image(systemSymbol: .clockFill)
                                        .renderingMode(.original)
                                    Text("Recent")
                                }
                                #if os(macOS)
                                .menuStyle(BorderlessButtonMenuStyle(showsMenuIndicator: true))
                                #elseif os(iOS)
                                .menuStyle(BorderlessButtonMenuStyle())
                                #endif
                                .fixedSize()
                            }

                            Spacer()

                        }

                    }
                }
                .padding()
                .frame(width: geometry.size.width)      // Make the scroll view full-width
                .frame(minHeight: geometry.size.height) // Set the content’s min height to the parent
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 500)
        #endif
        .alert(isPresented: $roomCtx.shouldShowDisconnectReason) {
            Alert(title: Text("Disconnected"),
                  message: Text("Reason: " + (roomCtx.latestError != nil
                                                ? String(describing: roomCtx.latestError!)
                                                : "Unknown")))
        }
    }
}
