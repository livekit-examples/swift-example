import SwiftUI

// Used to show debugging related information
final class DebugCtrl: ObservableObject {
    @Published var videoViewVisible: Bool = true
    @Published var showInformation: Bool = false
}
