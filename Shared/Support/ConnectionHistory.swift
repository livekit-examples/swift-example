import SwiftUI
import LiveKit

struct ConnectionHistory: Codable {

    let updated: Date
    let url: String
    let token: String
    let roomSid: String?
    let roomName: String?
    let participantSid: String
    let participantIdentity: String
    let participantName: String?
}

extension ConnectionHistory: Identifiable {

    var id: Int {
        self.hashValue
    }
}

extension ConnectionHistory: Hashable, Equatable {

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(token)
    }

    static func == (lhs: ConnectionHistory, rhs: ConnectionHistory) -> Bool {
        return lhs.url == rhs.url && lhs.token == rhs.token
    }
}

extension Sequence where Element == ConnectionHistory {

    var sortedByUpdated: [ConnectionHistory] {
        Array(self).sorted { $0.updated > $1.updated }
    }
}

extension Set where Element == ConnectionHistory {

    mutating func update(room: Room) {

        guard let url = room.url,
              let token = room.token,
              let localParticipant = room.localParticipant else { return }

        let element = ConnectionHistory(
            updated: Date(),
            url: url,
            token: token,
            roomSid: room.sid,
            roomName: room.name,
            participantSid: localParticipant.sid,
            participantIdentity: localParticipant.identity,
            participantName: localParticipant.name
        )

        self.update(with: element)
    }
}
