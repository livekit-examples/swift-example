import SwiftUI

struct ContentView: View {

    @EnvironmentObject var appCtrl: AppCtrl

    var body: some View {
//        NavigationView {
            if (appCtrl.connectionState == .connected) {
                RoomView()
            } else {
                ConnectView()
            }
//        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
