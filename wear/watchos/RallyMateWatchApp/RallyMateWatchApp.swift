#if canImport(RallyMateWatchKit)
import RallyMateWatchKit
#endif
#if canImport(RallyMateCore)
import RallyMateCore
#endif
import AppIntents
import SwiftUI
import WatchKit

enum RallyMateWorkoutStyle: String, AppEnum {
    case lastFormat
    case advantages
    case starPoint
    case goldenPoint
    case training

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Formato Momentum"
    )
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .lastFormat: "Ultimo formato",
        .advantages: "Vantaggi, 3 set",
        .starPoint: "Star Point FIP, 3 set",
        .goldenPoint: "Golden point, 3 set",
        .training: "Allenamento libero",
    ]

    var matchFormat: MatchFormat {
        switch self {
        case .lastFormat:
            LocalMatchStore().loadLastFormat()
        case .advantages:
            .advantageBo3
        case .starPoint:
            .starPointBo3
        case .goldenPoint:
            .goldenPointBo3
        case .training:
            .training
        }
    }
}

struct StartRallyMateWorkoutIntent: StartWorkoutIntent {
    static let title: LocalizedStringResource = "Avvia partita Momentum"
    static let description = IntentDescription(
        "Apre Momentum e avvia una partita con il formato scelto."
    )
    static let suggestedWorkouts: [Self] = [
        Self(style: .lastFormat),
        Self(style: .advantages),
        Self(style: .starPoint),
        Self(style: .goldenPoint),
        Self(style: .training),
    ]

    @Parameter(title: "Formato")
    var workoutStyle: RallyMateWorkoutStyle

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "Momentum",
            subtitle: workoutStyle.caseDisplayRepresentationsTitle
        )
    }

    init() {
        workoutStyle = .lastFormat
    }

    init(style: RallyMateWorkoutStyle) {
        workoutStyle = style
    }

    func perform() async throws -> some IntentResult {
        LocalMatchStore().requestSystemQuickStart(
            format: workoutStyle.matchFormat
        )
        return .result()
    }
}

private extension RallyMateWorkoutStyle {
    var caseDisplayRepresentationsTitle: LocalizedStringResource {
        switch self {
        case .lastFormat: "Ultimo formato"
        case .advantages: "Vantaggi, 3 set"
        case .starPoint: "Star Point FIP, 3 set"
        case .goldenPoint: "Golden point, 3 set"
        case .training: "Allenamento libero"
        }
    }
}

struct RallyMateAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRallyMateWorkoutIntent(),
            phrases: [
                "Avvia una partita con \(.applicationName)",
                "Inizia padel con \(.applicationName)",
            ],
            shortTitle: "Nuova partita",
            systemImageName: "figure.racquetball"
        )
    }
}

final class RallyMateWatchAppDelegate: NSObject, WKApplicationDelegate {
    /// watchOS relaunched us for a session it kept alive. Restore the recorded
    /// segments first so the re-attached session finalises exactly once.
    func handleActiveWorkoutRecovery() {
        Task { @MainActor in
            let store = LocalMatchStore()
            guard let matchId = store.workoutRecoveryMatchId()
                ?? store.activeMatchId()
            else { return }
            let mode = store.loadHealthRecordingMode(matchId)
                ?? store.loadDefaultHealthRecordingMode()
            let manager = WatchWorkoutSessionManager.shared
            manager.restore(
                matchId: matchId,
                mode: mode,
                segments: store.loadWorkoutSegments(matchId),
                state: store.loadRecordingState(matchId) ?? .idle
            )
            manager.recoverActiveSession(matchId: matchId, mode: mode)
        }
    }
}

@main
struct RallyMateWatchApp: App {
    @WKApplicationDelegateAdaptor private var appDelegate: RallyMateWatchAppDelegate

    var body: some Scene {
        WindowGroup {
            RallyMateWatchAppRoot()
        }
    }
}
