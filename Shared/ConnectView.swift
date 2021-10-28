import SwiftUI

final class ConnectViewCtrl: ObservableObject {

    let id = UUID()

    @Published var url: String = "wss://rtc.unxpected.co.jp"
    @Published var token: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2MzQ3MTkyOTEsIm5iZiI6MTYzNDcxNzQ5MSwiaXNzIjoiQVBJd2NWRFNSUjRTRkE2IiwianRpIjoiZGVidWciLCJ2aWRlbyI6eyJyb29tIjoicm9vbTYyNjlkMTk0LWRjMzQtNDYyMy1iOTkzLTA2YTBlMjQ2ODhiMyIsInJvb21DcmVhdGUiOnRydWUsInJvb21Kb2luIjp0cnVlLCJyb29tTGlzdCI6dHJ1ZSwicm9vbVJlY29yZCI6dHJ1ZSwicm9vbUFkbWluIjp0cnVlLCJjYW5QdWJsaXNoIjp0cnVlLCJjYW5TdWJzY3JpYmUiOnRydWV9fQ.FdHGpXXf0Q6eHGzHQIeH_5sV7o46hLRpyD66M9djCEY"

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

        ZStack {
//            LinearGradient(gradient: Gradient(colors: [.secondaryColor, .mainColor]),
//                           startPoint: .topLeading, endPoint: .bottomTrailing)
//                .ignoresSafeArea()

            VStack(alignment: .center, spacing: 30.0) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 100, height: 100)

                if (appCtrl.connectionState == .connected) {
                    Text("Connected")
                } else {
                    Text("Not connected")
                }

                Text(ctrl.url)

                TextField("URL", text: $ctrl.url)
                    .padding()
//                    .background(Color.inputBgColor)
                    .cornerRadius(10.0)

                TextField("Password", text: $ctrl.token)
                    .padding()
//                    .background(Color.inputBgColor)
                    .cornerRadius(10.0)

//                NavigationLink(destination: LazyView(ConnectView())) {
//
//                }

                if case .connecting = appCtrl.connectionState {
                    ProgressView()
                } else {
                    LKButton(title: "Connect") {
                        appCtrl.connect(url: ctrl.url, token: ctrl.token)
                    }
                }

            }
            .padding()

        }
        .alert(isPresented: $appCtrl.shouldShowError) {
            var message: Text?
            if case .disconnected(let error) = appCtrl.connectionState, error != nil {
                message = Text(error!.localizedDescription)
            }
            return Alert(title: Text("Error"), message: message)
        }
//        .navigationBarHidden(true)
    }
}
