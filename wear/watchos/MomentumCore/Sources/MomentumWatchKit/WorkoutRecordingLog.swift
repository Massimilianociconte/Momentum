import Foundation
import os

/// Structured, privacy-safe trace of the recording state machine.
///
/// Every line carries previous state, new state, reason, timestamp and the
/// HealthKit error code. Health values (heart rate, calories), account ids and
/// team names are never logged; the match id is truncated to a short opaque
/// prefix so support can correlate without storing an identifier.
public enum WatchWorkoutLog {
    private static let logger = Logger(
        subsystem: "com.rallymate.watch",
        category: "workout-recording"
    )

    /// Last transitions kept in memory for the in-app diagnostics row.
    private static let bufferLimit = 24
    private nonisolated(unsafe) static var buffer: [String] = []
    private static let bufferLock = NSLock()

    public static func log(_ transition: WatchRecordingTransition, matchId: String) {
        let line = format(transition, matchId: matchId)
        logger.log(
            """
            workout_transition match=\(token(matchId), privacy: .public) \
            from=\(transition.from.rawValue, privacy: .public) \
            to=\(transition.to.rawValue, privacy: .public) \
            reason=\(transition.reason.rawValue, privacy: .public) \
            ts=\(transition.at.timeIntervalSince1970, privacy: .public) \
            hkError=\(transition.healthKitErrorCode.map(String.init) ?? "-", privacy: .public)
            """
        )
        bufferLock.lock()
        buffer.append(line)
        if buffer.count > bufferLimit { buffer.removeFirst(buffer.count - bufferLimit) }
        bufferLock.unlock()
    }

    public static func recent() -> [String] {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        return buffer
    }

    static func format(_ transition: WatchRecordingTransition, matchId: String) -> String {
        let error = transition.healthKitErrorCode.map { " hk=\($0)" } ?? ""
        return "\(Int(transition.at.timeIntervalSince1970)) "
            + "\(token(matchId)) "
            + "\(transition.from.rawValue)->\(transition.to.rawValue) "
            + "\(transition.reason.rawValue)\(error)"
    }

    /// Opaque, stable, non-reversible short token for correlation only.
    static func token(_ matchId: String) -> String {
        guard !matchId.isEmpty else { return "-" }
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in matchId.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return String(format: "m%08x", UInt32(truncatingIfNeeded: hash))
    }
}
