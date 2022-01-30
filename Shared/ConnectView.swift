import SwiftUI
import LiveKit

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
                    }

                    VStack(spacing: 20) {
                        LKTextField(title: "Server URL", text: $roomCtx.url, type: .URL)
                        LKTextField(title: "Token", text: $roomCtx.token, type: .ascii)
                        Toggle(isOn: $roomCtx.simulcast) {
                            Text("Simulcast")
                                .fontWeight(.bold)
                        }.toggleStyle(SwitchToggleStyle(tint: Color.lkBlue))
                        // Not yet available
                        //                        Toggle(isOn: $ctrl.publish) {
                        //                            Text("Publish mode")
                        //                                .fontWeight(.bold)
                        //                        }.toggleStyle(SwitchToggleStyle(tint: Color.lkBlue))
                    }.frame(maxWidth: 350)

                    if case .connecting = roomCtx.connectionState {
                        ProgressView()
                    } else {
                        HStack(alignment: .center) {
                            Spacer()

                            LKButton(title: "Connect") {
                                roomCtx.connect()
                            }

                            if !appCtx.connectionHistory.isEmpty {
                                Menu {
                                    ForEach(appCtx.connectionHistory.view) { entry in
                                        Button {
                                            roomCtx.connect(entry: entry)
                                        } label: {
                                            Image(systemName: "bolt.horizontal.circle")
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
                                        Image(systemName: "xmark.circle.fill")
                                            .renderingMode(.original)
                                        Text("Clear history")
                                    }

                                } label: {
                                    Image(systemName: "clock.fill")
                                        .renderingMode(.original)
                                    Text("Recent")
                                }
                                .frame(minWidth: nil,
                                       maxWidth: 200,
                                       minHeight: nil,
                                       maxHeight: nil)
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
