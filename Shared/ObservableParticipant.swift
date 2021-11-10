import SwiftUI
import LiveKit

extension ObservableParticipant: ParticipantDelegate {

    func participant(_ participant: RemoteParticipant,
                     didSubscribe trackPublication: RemoteTrackPublication,
                     track: Track) {
        recomputeFirstTracks()
    }

    func participant(_ participant: RemoteParticipant,
                     didUnsubscribe trackPublication: RemoteTrackPublication,
                     track: Track) {
        recomputeFirstTracks()
    }

    func localParticipant(_ participant: LocalParticipant,
                          didPublish trackPublication: LocalTrackPublication) {
        recomputeFirstTracks()
    }

    func localParticipant(_ participant: LocalParticipant,
                          didUnpublish trackPublication: LocalTrackPublication) {
        recomputeFirstTracks()
    }

    func participant(_ participant: Participant,
                     didUpdate trackPublication: TrackPublication, muted: Bool) {
        recomputeFirstTracks()
    }

    func participant(_ participant: Participant, didUpdate speaking: Bool) {
        DispatchQueue.main.async {
            self.isSpeaking = speaking
        }
    }

    func participant(_ participant: Participant, didUpdate connectionQuality: ConnectionQuality) {
        DispatchQueue.main.async {
            self.connectionQuality = connectionQuality
        }
    }
}

extension ObservableParticipant: Identifiable {
    var id: String {
        participant.sid
    }
}

extension ObservableParticipant: Equatable & Hashable {

    static func == (lhs: ObservableParticipant, rhs: ObservableParticipant) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension ObservableParticipant {
    var identity: String? {
        participant.identity
    }
}

final class ObservableParticipant: ObservableObject {

    let participant: Participant

    @Published private(set) var firstVideo: TrackPublication? {
        didSet {
            if let pub = firstVideo, !pub.muted, firstVideo?.track != nil {
                firstVideoAvailable = true
            } else {
                firstVideoAvailable = false
            }

            self.firstVideoTrack = firstVideo?.track as? VideoTrack
        }
    }

    @Published private(set) var firstAudio: TrackPublication? {
        didSet {
            if let pub = firstAudio, !pub.muted, firstAudio?.track != nil {
                firstAudioAvailable = true
            } else {
                firstAudioAvailable = false
            }

            self.firstAudioTrack = firstAudio?.track as? AudioTrack
        }
    }

    @Published private(set) var firstVideoTrack: VideoTrack?
    @Published private(set) var firstAudioTrack: AudioTrack?

    @Published private(set) var firstVideoAvailable: Bool = false
    @Published private(set) var firstAudioAvailable: Bool = false
    @Published private(set) var isSpeaking: Bool = false

    @Published private(set) var connectionQuality: ConnectionQuality = .unknown

    init(_ participant: Participant) {
        self.participant = participant
        participant.add(delegate: self)
        recomputeFirstTracks()
    }

    deinit {
        participant.remove(delegate: self)
    }

    private func recomputeFirstTracks() {
        DispatchQueue.main.async {
            self.firstVideo = self.participant.videoTracks.values.first
            self.firstAudio = self.participant.audioTracks.values.first
        }
    }
}
