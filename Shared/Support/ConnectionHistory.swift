import SwiftUI
import LiveKit

typealias ConnectionHistory = Set<ConnectionHistoryEntry>

struct ConnectionHistoryEntry: Codable {
    let updated: Date
    let url: String
    let token: String
    let roomSid: String?
    let roomName: String?
    let participantIdentity: String
    let participantName: String?
}

extension ConnectionHistoryEntry: Identifiable {
    var id: Int {
        self.hashValue
    }
}

extension ConnectionHistoryEntry: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(token)
    }
}

extension ConnectionHistory: RawRepresentable {

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? Self.decoder.decode(Set<ConnectionHistoryEntry>.self, from: data)
        else { return nil }
        self = result
    }

    public var rawValue: String {
        guard let data = try? Self.encoder.encode(self),
              let result = String(data: data, encoding: .utf8)
        else { return "[]" }
        return result
    }

    public mutating func add(room: Room) {

        guard let url = room.url,
              let token = room.token,
              let localParticipant = room.localParticipant else { return }

        let element = ConnectionHistoryEntry(
            updated: Date(),
            url: url,
            token: token,
            roomSid: room.sid,
            roomName: room.name,
            participantIdentity: localParticipant.identity,
            participantName: localParticipant.name
        )

        self.insert(element)
    }
}
