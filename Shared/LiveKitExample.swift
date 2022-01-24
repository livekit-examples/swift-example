import SwiftUI

@main
struct LiveKitExample: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppCtrl.shared)
                .navigationTitle("LiveKit")
        }
    }
}
