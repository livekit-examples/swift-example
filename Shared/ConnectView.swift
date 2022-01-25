import SwiftUI

final class ConnectViewCtrl: ObservableObject {
    @AppStorage("url") var url: String = ""
    @AppStorage("token") var token: String = ""
    @AppStorage("simulcast") var simulcast: Bool = true
    @AppStorage("publish") var publish: Bool = false
}

struct ConnectView: View {

    @EnvironmentObject var appCtrl: AppContextCtrl
    @ObservedObject var ctrl = ConnectViewCtrl()

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .center, spacing: 60.0) {

                    Image("logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 40)

                    VStack(spacing: 30) {
                        LKTextField(title: "Server URL", text: $ctrl.url, type: .URL)
                        LKTextField(title: "Token", text: $ctrl.token, type: .ascii)
                        Toggle(isOn: $ctrl.simulcast) {
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
                        LKButton(title: "Connect") {
                            appCtrl.connect(url: ctrl.url,
                                            token: ctrl.token,
                                            simulcast: ctrl.simulcast,
                                            publish: ctrl.publish)
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
