import Foundation

/// Centralized limits for work that can wake the watch CPU or its radios.
/// Scoring and local persistence remain immediate; only derived UI updates and
/// best-effort transport are coalesced.
public enum WatchEnergyPolicy {
    public static let syncDebounce: Duration = .milliseconds(180)
    public static let workoutMetricPublishInterval: TimeInterval = 5
    public static let imageMaxPixelSize = 256
}
