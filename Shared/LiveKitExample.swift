import SwiftUI
import Logging
import LiveKit
import KeychainAccess

let sync = ValueStore<Preferences>(store: Keychain(service: "io.livekit.example"),
                                   key: "preferences",
                                   default: Preferences())

struct RoomContextView: View {

    @StateObject var roomCtx = RoomContext(store: sync)

    var shouldShowRoomView: Bool {
        roomCtx.connectionState.isConnected || roomCtx.connectionState.isReconnecting
    }

    func computeTitle() -> String {
        if shouldShowRoomView {
            let elements = [roomCtx.room.room.name,
                            roomCtx.room.room.localParticipant?.name,
                            roomCtx.room.room.localParticipant?.identity]
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

        }.foregroundColor(Color.white)
        .environmentObject(roomCtx)
        .environmentObject(roomCtx.room)
        .navigationTitle(computeTitle())
        .onDisappear {
            print("\(String(describing: type(of: self))) onDisappear")
            roomCtx.disconnect()
        }
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
        LoggingSystem.bootstrap({ LiveKitLogHandler(label: $0) })
    }

    var body: some Scene {
        WindowGroup {
            RoomContextView()
                .environmentObject(appCtx)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: true))
        #endif
    }
}
