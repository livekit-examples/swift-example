import SwiftUI
import LiveKit

struct ConnectView: View {

    @EnvironmentObject var appCtx: AppContextCtrl

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
                        LKTextField(title: "Server URL", text: $appCtx.url, type: .URL)
                        LKTextField(title: "Token", text: $appCtx.token, type: .ascii)
                        Toggle(isOn: $appCtx.simulcast) {
                            Text("Simulcast")
                                .fontWeight(.bold)
                        }.toggleStyle(SwitchToggleStyle(tint: Color.lkBlue))
                        // Not yet available
                        //                        Toggle(isOn: $ctrl.publish) {
                        //                            Text("Publish mode")
                        //                                .fontWeight(.bold)
                        //                        }.toggleStyle(SwitchToggleStyle(tint: Color.lkBlue))
                    }.frame(maxWidth: 350)

                    if case .connecting = appCtx.connectionState {
                        ProgressView()
                    } else {
                        HStack(alignment: .center) {
                            Spacer()

                            LKButton(title: "Connect") {
                                appCtx.connect()
                            }

                            if !appCtx.connectionHistory.isEmpty {
                                Menu {
                                    ForEach(Array(appCtx.connectionHistory)) { entry in
                                        Button {
                                            appCtx.connect(entry: entry)
                                        } label: {
                                            Text([entry.roomName,
                                                  entry.participantIdentity,
                                                  entry.url].compactMap { $0 }.joined(separator: " "))
                                            Image(systemName: "bolt.horizontal.circle")
                                        }
                                    }

                                } label: {
                                    Image(systemName: "clock.fill")
                                    Text("Recent")
                                }
                                .menuStyle(.borderedButton)
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

        .alert(isPresented: $appCtx.shouldShowError) {
            Alert(title: Text("Error"),
                  message: Text(appCtx.latestError != nil
                                    ? String(describing: appCtx.latestError!)
                                    : "Unknown error"))
        }
    }
}
