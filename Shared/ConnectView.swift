import SwiftUI
import LiveKit

struct ConnectView: View {

    @EnvironmentObject var appCtrl: AppContextCtrl

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
                        LKTextField(title: "Server URL", text: $appCtrl.url, type: .URL)
                        LKTextField(title: "Token", text: $appCtrl.token, type: .ascii)
                        Toggle(isOn: $appCtrl.simulcast) {
                            Text("Simulcast")
                                .fontWeight(.bold)
                        }.toggleStyle(SwitchToggleStyle(tint: Color.lkBlue))
                        // Not yet available
                        //                        Toggle(isOn: $ctrl.publish) {
                        //                            Text("Publish mode")
                        //                                .fontWeight(.bold)
                        //                        }.toggleStyle(SwitchToggleStyle(tint: Color.lkBlue))
                    }.frame(maxWidth: 350)

                    if case .connecting = appCtrl.connectionState {
                        ProgressView()
                    } else {
                        HStack(alignment: .center) {
                            Spacer()

                            LKButton(title: "Connect") {
                                appCtrl.connect()
                            }

                            if !appCtrl.connectionHistory.isEmpty {
                                Menu {
                                    ForEach(appCtrl.connectionHistory.view) { entry in
                                        Button {
                                            appCtrl.connect(entry: entry)
                                        } label: {
                                            Image(systemName: "bolt.horizontal.circle")
                                            Text([entry.roomName,
                                                  entry.participantIdentity,
                                                  entry.url].compactMap { $0 }.joined(separator: " "))
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    Button {
                                        appCtrl.connectionHistory.removeAll()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .renderingMode(.original)
                                        Text("Clear history")
                                    }

                                } label: {
                                    Image(systemName: "clock.fill")
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

        .alert(isPresented: $appCtrl.shouldShowError) {
            Alert(title: Text("Error"),
                  message: Text(appCtrl.latestError != nil
                                    ? String(describing: appCtrl.latestError!)
                                    : "Unknown error"))
        }
    }
}
