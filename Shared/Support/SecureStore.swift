import SwiftUI
import KeychainAccess
import Combine
import LiveKit

struct Preferences: Codable, Equatable {
    var url = ""
    var token = ""
    var e2eeKey = ""
    var e2ee = false

    // Connect options
    var autoSubscribe = true
    var publishMode = false

    // Room options
    var simulcast = true
    var adaptiveStream = true
    var dynacast = true
    var reportStats = true

    // Settings
    var videoViewVisible = true
    var showInformationOverlay = false
    var preferMetal = true
    var videoViewMode: VideoView.LayoutMode = .fit
    var videoViewMirrored = false

    var connectionHistory = Set<ConnectionHistory>()
}

let encoder = JSONEncoder()
let decoder = JSONDecoder()

class ValueStore<T: Codable & Equatable>: ObservableObject {

    private let store: Keychain
    private let key: String
    private let message = ""
    private weak var timer: Timer?

    public var value: T {
        didSet {
            guard oldValue != value else { return }
            lazySync()
        }
    }

    private var storeWithOptions: Keychain {
        store
            .accessibility(.whenUnlocked)
            .synchronizable(true)
    }

    public init(store: Keychain, key: String, `default`: T) {
        self.store = store
        self.key = key
        self.value = `default`

        if let data = try? storeWithOptions.getData(key),
           let result = try? decoder.decode(T.self, from: data) {
            self.value = result
        }
    }

    deinit {
        timer?.invalidate()
    }

    public func lazySync() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1,
                                     repeats: false,
                                     block: { _ in self.sync() })
    }

    public func sync() {
        do {
            let data = try encoder.encode(value)
            try self.storeWithOptions.set(data, key: key)
        } catch let error {
            print("Failed to write in Keychain, error: \(error)")
        }
    }
}
