import SwiftUI

struct ContentView: View {

    @EnvironmentObject var appCtrl: AppCtrl

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let room = appCtrl.room {
                RoomView(room)
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
