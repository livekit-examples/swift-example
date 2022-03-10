import SwiftUI
import KeychainAccess
import Combine
import LiveKit
import Promises

struct Preferences: Codable, Equatable {
    var url = ""
    var token = ""

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

// Promise version
extension Keychain {

    @discardableResult
    func get<T: Decodable>(_ key: String) -> Promise<T?> {
        Promise(on: .global()) { () -> T? in
            guard let data = try self.getData(key) else { return nil }
            return try decoder.decode(T.self, from: data)
        }
    }

    @discardableResult
    func set<T: Encodable>(_ key: String, value: T) -> Promise<Void> {
        Promise(on: .global()) { () -> Void in
            let data = try encoder.encode(value)
            try self.set(data, key: key)
        }
    }
}

class ValueStore<T: Codable & Equatable>: ObservableObject {

    private let store: Keychain
    private let key: String
    private let message = ""
    private weak var timer: Timer?

    public let onLoaded = Promise<T>.pending()

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

        storeWithOptions.get(key).then { (result: T?) -> Void in
            self.value = result ?? self.value
            self.onLoaded.fulfill(self.value)
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
        storeWithOptions.set(key, value: value).catch { error in
            print("Failed to write in Keychain, error: \(error)")
        }
    }
}
