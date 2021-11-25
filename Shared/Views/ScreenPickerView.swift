import SwiftUI
import LiveKit

final class ScreenPickerCtrl: ObservableObject {

    private var tracks = [LocalVideoTrack]()
    @Published var startedTracks = [LocalVideoTrack]()

    init() {
        print("ScreenPickerCtrl.init()")

        let displayIds = MacOSScreenCapturer.displayIDs()

        self.tracks = displayIds.map { LocalVideoTrack.createMacOSScreenShareTrack(displayId: $0) }

        for track in self.tracks {
            track.start().then {
                DispatchQueue.main.async {
                    self.startedTracks.append(track)
                }
            }
        }
    }

    deinit {
        print("ScreenPickerCtrl.deinit")
    }

}

extension LocalVideoTrack: Identifiable {
    public var id: ObjectIdentifier {
        return ObjectIdentifier(self)
    }
}

typealias OnDidPickScreen = (CGDirectDisplayID) -> Void

struct ScreenPickerView: View {

    @ObservedObject var ctrl = ScreenPickerCtrl()
    let onDidPickScreen: OnDidPickScreen?

    private var columns = [
        GridItem(.fixed(250))
    ]

    init(onPick: OnDidPickScreen? = nil) {
        self.onDidPickScreen = onPick
    }

    var body: some View {

        //        ScrollView(.vertical, showsIndicators: true) {
        LazyVGrid(columns: columns,
                  alignment: .center,
                  spacing: 10) {

            ForEach(ctrl.startedTracks) { track in
                SwiftUIVideoView(track, mode: .fill)
                    .aspectRatio(1, contentMode: .fit)
                    .onTapGesture {
                        guard let capturer = track.capturer as? MacOSScreenCapturer else { return }
                        print("Display: \(capturer.displayId)")
                        onDidPickScreen?(capturer.displayId)
                    }
            }
        }

    }
}
