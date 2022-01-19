import SwiftUI

@main
struct LiveKitExample: App {

    @StateObject private var appState = AppCtrl.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .navigationTitle("LiveKit")
        }
    }
}
