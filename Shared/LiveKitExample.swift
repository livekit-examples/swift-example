import SwiftUI
import Logging
import LiveKit
import KeychainAccess

let sync = ValueStore<Preferences>(store: Keychain(service: "io.livekit.example.SwiftSDK.1"),
                                   key: "preferences",
                                   default: Preferences())

struct RoomContextView: View {

    @EnvironmentObject var appCtx: AppContext
    @StateObject var roomCtx = RoomContext(store: sync)

    var shouldShowRoomView: Bool {
        roomCtx.room.connectionState.isConnected || roomCtx.room.connectionState.isReconnecting
    }

    func computeTitle() -> String {
        if shouldShowRoomView {
            let elements = [roomCtx.room.name,
                            roomCtx.room.localParticipant?.name,
                            roomCtx.room.localParticipant?.identity]
            return elements.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
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
        .environment(\.colorScheme, .dark)
        .foregroundColor(Color.white)
        .environmentObject(roomCtx)
        .environmentObject(roomCtx.room)
        .navigationTitle(computeTitle())
        .onDisappear {
            print("\(String(describing: type(of: self))) onDisappear")
            Task {
                try await roomCtx.disconnect()
            }
        }
        .onOpenURL(perform: { url in

            guard let urlComponent = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
            guard let host = url.host else { return }

            let secureValue = urlComponent.queryItems?.first(where: { $0.name == "secure" })?.value?.lowercased()
            let secure = ["true", "1"].contains { $0 == secureValue }

            let tokenValue = urlComponent.queryItems?.first(where: { $0.name == "token" })?.value ?? ""

            var builder = URLComponents()
            builder.scheme = secure ? "wss" : "ws"
            builder.host = host
            builder.port = url.port

            guard let builtUrl = builder.url?.absoluteString else { return }

            print("built URL: \(builtUrl), token: \(tokenValue)")

            Task { @MainActor in
                roomCtx.url = builtUrl
                roomCtx.token = tokenValue
                if !roomCtx.token.isEmpty {
                    let room = try await roomCtx.connect()
                    appCtx.connectionHistory.update(room: room)
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
        LoggingSystem.bootstrap({
            var logHandler = StreamLogHandler.standardOutput(label: $0)
            logHandler.logLevel = .debug
            return logHandler
        })
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
        self.background(HostingWindowFinder(callback: callback))
    }
}

struct HostingWindowFinder: NSViewRepresentable {
    var callback: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            if let window = view?.window {
                self.callback(window)
            }
        }
        return view
    }

    func updateNSView(_ uiView: NSView, context: Context) {}
}
#endif
