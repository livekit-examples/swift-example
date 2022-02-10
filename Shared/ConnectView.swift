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

                    VStack(spacing: 20) {
                        Image("logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 40)
                        Text("SDK Version \(LiveKit.version)")
                        Text("Example App Version \(Bundle.main.appVersionLong) (\(Bundle.main.appBuild))")
                    }

                    VStack(spacing: 20) {
                        LKTextField(title: "Server URL", text: $roomCtx.url, type: .URL)
                        LKTextField(title: "Token", text: $roomCtx.token, type: .ascii)

                        HStack {
                            Menu {
                                Toggle(isOn: $roomCtx.autoSubscribe) {
                                    Text("Auto-Subscribe")
                                }
                                Toggle(isOn: $roomCtx.publish) {
                                    Text("Publish only mode")
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
                            } label: {
                                Image(systemName: SFSymbol.gear.rawValue)
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

                    if case .connecting = roomCtx.connectionState {
                        ProgressView()
                    } else {
                        HStack(alignment: .center) {
                            Spacer()

                            LKButton(title: "Connect") {
                                roomCtx.connect().then { room in
                                    appCtx.connectionHistory.update(room: room)
                                }
                            }

                            if !appCtx.connectionHistory.isEmpty {
                                Menu {
                                    ForEach(appCtx.connectionHistory.sortedByUpdated) { entry in
                                        Button {
                                            roomCtx.connect(entry: entry).then { room in
                                                appCtx.connectionHistory.update(room: room)
                                            }
                                        } label: {
                                            Image(systemName: SFSymbol.boltFill.rawValue)
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
                                        Image(systemName: SFSymbol.xmarkCircleFill.rawValue)
                                            .renderingMode(.original)
                                        Text("Clear history")
                                    }

                                } label: {
                                    Image(systemName: SFSymbol.clockFill.rawValue)
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

        .alert(isPresented: $roomCtx.shouldShowError) {
            Alert(title: Text("Error"),
                  message: Text(roomCtx.latestError != nil
                                    ? String(describing: roomCtx.latestError!)
                                    : "Unknown error"))
        }
    }
}
