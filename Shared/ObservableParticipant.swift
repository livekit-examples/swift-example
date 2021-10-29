import SwiftUI
import LiveKit

extension ObservableParticipant: ParticipantDelegate {

    func participant(_ participant: RemoteParticipant,
                     didSubscribe trackPublication: RemoteTrackPublication,
                     track: Track) {
        recomputeFirstVideoTrack()
    }

    func participant(_ participant: RemoteParticipant,
                     didUnsubscribe trackPublication: RemoteTrackPublication,
                     track: Track) {
        recomputeFirstVideoTrack()
    }

    func participant(_ participant: Participant, didUpdate speaking: Bool) {
        DispatchQueue.main.async {
            self.isSpeaking = speaking
        }
    }
}

extension ObservableParticipant: Identifiable {
    var id: String {
        participant.sid
    }
}

extension ObservableParticipant {
    var identity: String? {
        participant.identity
    }
}

final class ObservableParticipant: ObservableObject {

    let participant: Participant

    @Published var firstVideoTrack: VideoTrack?
    @Published var isSpeaking: Bool = false

    init(_ participant: Participant) {
        self.participant = participant
        participant.add(delegate: self)
        recomputeFirstVideoTrack()
    }

    deinit {
        participant.remove(delegate: self)
    }

    private func recomputeFirstVideoTrack() {
        DispatchQueue.main.async {
            self.firstVideoTrack = self.participant.videoTracks.values.first?.track as? VideoTrack
        }
    }
}
