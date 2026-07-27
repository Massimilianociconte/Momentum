import Foundation
#if canImport(MomentumCore)
import MomentumCore
#endif

#if os(watchOS)
import WatchKit
#endif

public protocol WatchHaptics {
    func play(_ transitions: [Transition])
    func playError()
    func playSuccess()
}

public extension WatchHaptics {
    func playError() {}
    func playSuccess() {}
}

/// Semantic haptics for PRD D1/D2.
///
/// Apple Watch exposes predefined haptic types rather than arbitrary vibration
/// durations, so we map the product intent to the closest watch-native signals:
/// point = click, undo = retry, game/set = success, match = notification.
public struct SystemWatchHaptics: WatchHaptics {
    public init() {}

    public func play(_ transitions: [Transition]) {
        #if os(watchOS)
        let device = WKInterfaceDevice.current()
        switch true {
        case transitions.contains(.matchWon):
            device.play(.notification)
        case transitions.contains(.setWon), transitions.contains(.gameWon):
            device.play(.success)
        case transitions.contains(.undone):
            device.play(.retry)
        case transitions.contains(.point):
            device.play(.click)
        default:
            break
        }
        #else
        _ = transitions
        #endif
    }

    public func playError() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.failure)
        #endif
    }

    public func playSuccess() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.success)
        #endif
    }
}

public struct NoopWatchHaptics: WatchHaptics {
    public init() {}
    public func play(_: [Transition]) {}
}
