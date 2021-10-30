import SwiftUI

final class ConnectViewCtrl: ObservableObject {

    let id = UUID()

    @AppStorage("url") var url: String = ""
    @AppStorage("token") var token: String = ""

    init() {
        print("ConnectViewCtrl init \(id)")
    }

    deinit {
        print("ConnectViewCtrl deinit \(id)")
    }
}

struct ConnectView: View {

    @EnvironmentObject var appCtrl: AppCtrl
    @ObservedObject var ctrl = ConnectViewCtrl()

    @State var isModalActive: Bool = true

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .center, spacing: 60.0) {

                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 40)

                    VStack(spacing: 30) {
                        LKTextField(title: "Server URL", text: $ctrl.url, type: .URL)
                        LKTextField(title: "Token", text: $ctrl.token, type: .ascii)
                    }.frame(maxWidth: 350)

                    if case .connecting = appCtrl.connectionState {
                        ProgressView()
                    } else {
                        LKButton(title: "Connect") {
                            appCtrl.connect(url: ctrl.url, token: ctrl.token)
                        }
                    }
                }
                .padding()
                .frame(width: geometry.size.width)      // Make the scroll view full-width
                .frame(minHeight: geometry.size.height) // Set the content’s min height to the parent
            }
        }

        .alert(isPresented: $appCtrl.shouldShowError) {
            var message: Text?
            if case .disconnected(let error) = appCtrl.connectionState, error != nil {
                message = Text(error!.localizedDescription)
            }
            return Alert(title: Text("Error"), message: message)
        }
    }
}
