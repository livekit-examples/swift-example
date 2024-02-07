/*
 * Copyright 2024 LiveKit
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

let sync = ValueStore<Preferences>(store: Keychain(service: "io.livekit.example.SwiftSDK.1"),
                                   key: "preferences",
                                   default: Preferences())

struct RoomSwitchView: View {
    @EnvironmentObject var appCtx: AppContext
    @EnvironmentObject var roomCtx: RoomContext
    @EnvironmentObject var room: Room

    var shouldShowRoomView: Bool {
        room.connectionState == .connected || room.connectionState == .reconnecting
    }

    func computeTitle() -> String {
        if shouldShowRoomView {
            let elements = [room.name,
                            room.localParticipant.name,
                            room.localParticipant.identity] as [Any]
            return elements.compactMap { String(describing: $0) }.filter { !$0.isEmpty }.joined(separator: " ")
        }

        return "LiveKit"
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if shouldShowRoomView {
                RoomView()
            } else {
                ConnectView()
            }
        }
        .navigationTitle(computeTitle())
    }
}

// Attaches RoomContext and Room to the environment
struct RoomContextView: View {
    @EnvironmentObject var appCtx: AppContext
    @StateObject var roomCtx = RoomContext(store: sync)

    var body: some View {
        RoomSwitchView()
            .environmentObject(roomCtx)
            .environmentObject(roomCtx.room)
            .environment(\.colorScheme, .dark)
            .foregroundColor(Color.white)
            .onDisappear {
                print("\(String(describing: type(of: self))) onDisappear")
                Task {
                    await roomCtx.disconnect()
                }
            }
            .onOpenURL(perform: { url in

                guard let urlComponent = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
                guard let host = url.host else { return }

                let secureValue = urlComponent.queryItems?.first(where: { $0.name == "secure" })?.value?.lowercased()
                let secure = ["true", "1"].contains { $0 == secureValue }

                let tokenValue = urlComponent.queryItems?.first(where: { $0.name == "token" })?.value ?? ""

                let e2eeValue = urlComponent.queryItems?.first(where: { $0.name == "e2ee" })?.value?.lowercased()
                let e2ee = ["true", "1"].contains { $0 == secureValue }
                let e2eeKey = urlComponent.queryItems?.first(where: { $0.name == "e2eeKey" })?.value ?? ""

                var builder = URLComponents()
                builder.scheme = secure ? "wss" : "ws"
                builder.host = host
                builder.port = url.port

                guard let builtUrl = builder.url?.absoluteString else { return }

                print("built URL: \(builtUrl), token: \(tokenValue)")

                Task { @MainActor in
                    roomCtx.url = builtUrl
                    roomCtx.token = tokenValue
                    roomCtx.isE2eeEnabled = e2ee
                    roomCtx.e2eeKey = e2eeKey
                    if !roomCtx.token.isEmpty {
                        let room = try await roomCtx.connect()
                        appCtx.connectionHistory.update(room: room, e2ee: e2ee, e2eeKey: e2eeKey)
                    }
                }
            })
    }
}

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
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
        #if os(macOS)
            .windowStyle(.hiddenTitleBar)
            .windowToolbarStyle(.unifiedCompact)
        #endif
    }
}

#if os(macOS)

    extension View {
        func withHostingWindow(_ callback: @escaping (NSWindow) -> Void) -> some View {
            background(HostingWindowFinder(callback: callback))
        }
    }

    struct HostingWindowFinder: NSViewRepresentable {
        var callback: (NSWindow) -> Void

        func makeNSView(context _: Context) -> NSView {
            let view = NSView()
            DispatchQueue.main.async { [weak view] in
                if let window = view?.window {
                    callback(window)
                }
            }
            return view
        }

        func updateNSView(_: NSView, context _: Context) {}
    }
#endif
