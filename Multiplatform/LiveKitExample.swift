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

import KeychainAccess
import LiveKit
import Logging
import SwiftUI

@MainActor let sync = ValueStore<Preferences>(store: Keychain(service: "io.livekit.example.SwiftSDK.1"),
                                              key: "preferences",
                                              default: Preferences())

extension Decimal {
    mutating func round(_ scale: Int, _ roundingMode: NSDecimalNumber.RoundingMode) {
        var localCopy = self
        NSDecimalRound(&self, &localCopy, scale, roundingMode)
    }

    func rounded(_ scale: Int, _ roundingMode: NSDecimalNumber.RoundingMode) -> Decimal {
        var result = Decimal()
        var localCopy = self
        NSDecimalRound(&result, &localCopy, scale, roundingMode)
        return result
    }

    func remainder(of divisor: Decimal) -> Decimal {
        let s = self as NSDecimalNumber
        let d = divisor as NSDecimalNumber
        let b = NSDecimalNumberHandler(roundingMode: .down,
                                       scale: 0,
                                       raiseOnExactness: false,
                                       raiseOnOverflow: false,
                                       raiseOnUnderflow: false,
                                       raiseOnDivideByZero: false)
        let quotient = s.dividing(by: d, withBehavior: b)

        let subtractAmount = quotient.multiplying(by: d)
        return s.subtracting(subtractAmount) as Decimal
    }
}

@main
struct LiveKitExample: App {
    @StateObject var appCtx = AppContext(store: sync)

    #if os(visionOS)
        @Environment(\.openWindow) var openWindow
    #endif

    func nearestSafeScale(for target: Int, scale: Double) -> Decimal {
        let p = Decimal(sign: .plus, exponent: -3, significand: 1)
        let t = Decimal(target)
        var s = Decimal(scale).rounded(3, .down)

        while (t * s / 2).remainder(of: 2) != 0 {
            s = s + p
        }

        return s
    }

    init() {
        LoggingSystem.bootstrap {
            var logHandler = StreamLogHandler.standardOutput(label: $0)
            logHandler.logLevel = .debug
            return logHandler
        }
    }

    var body: some Scene {
        WindowGroup {
            RoomContextView()
                .environmentObject(appCtx)
        }
        #if !os(tvOS)
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
        #endif
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        #endif

        #if os(visionOS)
            ImmersiveSpace(id: "ImmersiveSpace") {
                ImmersiveView()
            }
            .immersionStyle(selection: .constant(.full), in: .full)
        #endif
    }
}
