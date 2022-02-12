import SwiftUI
import KeychainAccess
import Combine

enum SecureStoreKeys: String {
    case url = "url"
    case token = "token"

    // Connect options
    case autoSubscribe = "autoSubscribe"
    case publishMode = "publishMode"

    // Room options
    case simulcast = "simulcast"
    case adaptiveStream = "adaptiveStream"
    case dynacast = "dynacast"

    // Settings
    case videoViewVisible = "videoViewVisible"
    case showInformationOverlay = "showInformationOverlay"
    case preferMetal = "preferMetal"
    case videoViewMode = "videoViewMode"
    case videoViewMirrored = "videoViewMirrored"

    case connectionHistory = "connectionHistory"
}

class SecureStore<K: RawRepresentable> where K.RawValue == String {

    let keychain: Keychain
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    init(service: String) {
        self.keychain = Keychain(service: service)
    }

    func get<T: Decodable>(_ key: K) -> T? {
        guard let data = try? keychain.getData(key.rawValue) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    func set<T: Encodable>(_ key: K, value: T) {
        guard let data = try? encoder.encode(value) else { return }
        try? keychain.set(data, key: key.rawValue)
    }
}
