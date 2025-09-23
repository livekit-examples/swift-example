/*
 * Copyright 2025 LiveKit
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Combine
import KeychainAccess
import LiveKit
import SwiftUI

struct Preferences: Codable, Equatable {
    var url = ""
    var token = ""
    var e2eeKey = ""
    var isE2eeEnabled = false

    // Connect options
    var autoSubscribe = true

    // Room options
    var simulcast = true
    var adaptiveStream = true
    var dynacast = true
    var reportStats = true

    // Settings
    var videoViewVisible = true
    var showInformationOverlay = false
    var preferSampleBufferRendering = false
    var videoViewMode: VideoView.LayoutMode = .fit
    var videoViewMirrored = false

    var connectionHistory = Set<ConnectionHistory>()
}

let encoder = JSONEncoder()
let decoder = JSONDecoder()

@MainActor
final class ValueStore<T: Codable & Equatable> {
    private let store: Keychain
    private let key: String
    private let message = ""
    private var syncTask: Task<Void, Never>?

    var value: T {
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

    init(store: Keychain, key: String, default: T) {
        self.store = store
        self.key = key
        value = `default`

        if let data = try? storeWithOptions.getData(key),
           let result = try? decoder.decode(T.self, from: data)
        {
            value = result
        }
    }

    deinit {
        syncTask?.cancel()
    }

    func lazySync() {
        syncTask?.cancel()
        syncTask = Task {
            try? await Task.sleep(nanoseconds: 1 * NSEC_PER_SEC)
            guard !Task.isCancelled else { return }
            sync()
        }
    }

    func sync() {
        do {
            let data = try encoder.encode(value)
            try storeWithOptions.set(data, key: key)
        } catch {
            print("Failed to write in Keychain, error: \(error)")
        }
    }
}
