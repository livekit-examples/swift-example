import SwiftUI

struct ContentView: View {

    @EnvironmentObject var appCtrl: AppCtrl

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if appCtrl.connectionState.isConnected ||
                appCtrl.connectionState.isReconnecting {

                RoomView(appCtrl.room)
                    .environmentObject(DebugCtrl())
            } else {
                ConnectView()
            }

        }.foregroundColor(Color.white)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
