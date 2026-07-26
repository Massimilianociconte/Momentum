@testable import RallyMateWatchKit
import XCTest

/// Ownership matrix for the single HealthKit recording per match.
/// Mirrors the mandatory manual test list: 90-minute match, external workout
/// before/after, background, watch face, phone disconnection, force quit,
/// denied permissions, pause/resume, finish, double tap, duplicate callbacks.
final class WorkoutRecordingPolicyTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func at(_ minutes: Double) -> Date {
        start.addingTimeInterval(minutes * 60)
    }

    // MARK: - 1. Full 90-minute match owned by RallyMate

    func testNinetyMinuteMatchProducesOneSavedSegment() {
        var machine = WorkoutRecordingStateMachine(mode: .rallyMateManaged)

        XCTAssertTrue(machine.requestStart(at: at(0)).decision.isStart)
        machine.apply(.startAccepted, at: at(0))
        XCTAssertEqual(machine.state, .running)

        machine.apply(.stopRequested(.matchFinished), at: at(90))
        machine.apply(.sessionEnded, at: at(90))
        machine.apply(.finalizeSucceeded, at: at(90))

        XCTAssertEqual(machine.state, .saved)
        XCTAssertEqual(machine.acceptedStarts, 1)
        XCTAssertEqual(machine.segments.count, 1)
        XCTAssertTrue(machine.segments[0].saved)

        let quality = machine.quality(matchStart: at(0), matchEnd: at(90))
        XCTAssertEqual(quality.completeness, .complete)
        XCTAssertEqual(quality.recordedDuration, 90 * 60, accuracy: 1)
        XCTAssertEqual(quality.coverage, 1, accuracy: 0.001)
    }

    /// Scoring must never re-arm the recording: this is the regression that
    /// produced restart ping-pong and 5-minute fragments.
    func testScoringTapsNeverStartASecondSession() {
        var machine = WorkoutRecordingStateMachine(mode: .rallyMateManaged)
        XCTAssertTrue(machine.requestStart(at: at(0)).decision.isStart)
        machine.apply(.startAccepted, at: at(0))

        for minute in stride(from: 1.0, through: 89.0, by: 1.0) {
            let (decision, _) = machine.requestStart(at: at(minute))
            XCTAssertEqual(decision, .rejected(.duplicateStartIgnored))
        }

        XCTAssertEqual(machine.acceptedStarts, 1)
        XCTAssertEqual(machine.segments.count, 1)
    }

    // MARK: - 2/3. Another app owns the workout

    func testExternalModeNeverCreatesASession() {
        var machine = WorkoutRecordingStateMachine(mode: .externalManaged)
        let (decision, transition) = machine.requestStart(at: at(0))

        XCTAssertEqual(decision, .rejected(.userChoiceExternal))
        XCTAssertEqual(transition?.reason, .userChoiceExternal)
        XCTAssertEqual(machine.state, .externalOwned)
        XCTAssertEqual(machine.acceptedStarts, 0)
        XCTAssertTrue(machine.segments.isEmpty)

        let quality = machine.quality(matchStart: at(0), matchEnd: at(90))
        XCTAssertEqual(quality.completeness, .external)
    }

    func testDisabledModeNeverCreatesASession() {
        var machine = WorkoutRecordingStateMachine(mode: .disabled)
        let (decision, _) = machine.requestStart(at: at(0))

        XCTAssertEqual(decision, .rejected(.userChoiceDisabled))
        XCTAssertEqual(machine.state, .disabled)
        XCTAssertEqual(machine.acceptedStarts, 0)
        XCTAssertEqual(
            machine.quality(matchStart: at(0), matchEnd: at(90)).completeness,
            .none
        )
    }

    /// Apple Allenamento already running: session creation fails with
    /// `errorAnotherWorkoutSessionStarted` (code 8) before anything is recorded.
    func testPreemptionAtStartLeavesNoSegmentAndNoRetryLoop() {
        var machine = WorkoutRecordingStateMachine(mode: .rallyMateManaged)
        XCTAssertTrue(machine.requestStart(at: at(0)).decision.isStart)
        machine.apply(.preempted(code: 8), at: at(0))
        machine.apply(.finalizeFailed(code: nil), at: at(0))

        XCTAssertEqual(machine.state, .externalOwned)
        XCTAssertEqual(machine.lastErrorCode, 8)

        for minute in stride(from: 1.0, through: 30.0, by: 1.0) {
            let (decision, _) = machine.requestStart(at: at(minute))
            XCTAssertEqual(decision, .rejected(.autoRestartSuppressed))
        }
        XCTAssertEqual(machine.acceptedStarts, 1)
        XCTAssertTrue(machine.segments.isEmpty)
    }

    /// Apple Allenamento started mid-match: the RallyMate segment that did run
    /// is finalised, marked partial, and never restarted automatically.
    func testPreemptionMidMatchSavesPartialSegmentWithoutRestart() {
        var machine = WorkoutRecordingStateMachine(mode: .rallyMateManaged)
        XCTAssertTrue(machine.requestStart(at: at(0)).decision.isStart)
        machine.apply(.startAccepted, at: at(0))

        // Another app takes the session after 5 minutes.
        machine.apply(.preempted(code: 8), at: at(5))
        XCTAssertEqual(machine.state, .finalizing)
        machine.apply(.finalizeSucceeded, at: at(5))

        XCTAssertEqual(machine.state, .externalOwned)
        XCTAssertEqual(machine.segments.count, 1)
        XCTAssertTrue(machine.segments[0].saved)
        XCTAssertEqual(
            machine.segments[0].endReason,
            WatchRecordingReason.preemptedByOtherApp.rawValue
        )

        let (decision, _) = machine.requestStart(at: at(6))
        XCTAssertEqual(decision, .rejected(.autoRestartSuppressed))

        let quality = machine.quality(matchStart: at(0), matchEnd: at(90))
        XCTAssertEqual(quality.completeness, .partial)
        XCTAssertTrue(quality.isPartial)
        XCTAssertEqual(quality.recordedDuration, 5 * 60, accuracy: 1)
        XCTAssertLessThan(quality.coverage, 0.1)
    }

    func testExplicitUserRestartOpensASecondSegmentOnly() {
        var machine = WorkoutRecordingStateMachine(mode: .rallyMateManaged)
        XCTAssertTrue(machine.requestStart(at: at(0)).decision.isStart)
        machine.apply(.startAccepted, at: at(0))
        machine.apply(.preempted(code: 8), at: at(5))
        machine.apply(.finalizeSucceeded, at: at(5))

        let (decision, _) = machine.requestStart(at: at(20), userInitiated: true)
        XCTAssertTrue(decision.isStart)
        machine.apply(.startAccepted, at: at(20))
        machine.apply(.stopRequested(.matchFinished), at: at(90))
        machine.apply(.sessionEnded, at: at(90))
        machine.apply(.finalizeSucceeded, at: at(90))

        XCTAssertEqual(machine.segments.count, 2)
        let quality = machine.quality(matchStart: at(0), matchEnd: at(90))
        XCTAssertEqual(quality.completeness, .partial)
        // 5 + 70 minutes, never the 90 of the match.
        XCTAssertEqual(quality.recordedDuration, 75 * 60, accuracy: 1)
        XCTAssertEqual(quality.segmentCount, 2)
    }

    func testOverlappingSegmentsAreMergedNotSummed() {
        var machine = WorkoutRecordingStateMachine(mode: .rallyMateManaged)
        machine.restore(
            segments: [
                WatchWorkoutSegment(startedAt: at(0), endedAt: at(30), saved: true),
                WatchWorkoutSegment(startedAt: at(20), endedAt: at(50), saved: true),
            ],
            state: .saved
        )
        let quality = machine.quality(matchStart: at(0), matchEnd: at(90))
        XCTAssertEqual(quality.recordedDuration, 50 * 60, accuracy: 1)
    }

    func testSegmentsAreClippedToTheMatchWindow() {
        var machine = WorkoutRecordingStateMachine(mode: .rallyMateManaged)
        machine.restore(
            segments: [
                WatchWorkoutSegment(startedAt: at(-10), endedAt: at(100), saved: true),
            ],
            state: .saved
        )
        let quality = machine.quality(matchStart: at(0), matchEnd: at(90))
        XCTAssertEqual(quality.recordedDuration, 90 * 60, accuracy: 1)
        XCTAssertEqual(quality.completeness, .complete)
    }

    // MARK: - 4/5/6. Background, watch face, phone disconnection

    func testBackgroundAndWatchFaceDoNotCloseTheRecording() {
        var machine = WorkoutRecordingStateMachine(mode: .rallyMateManaged)
        XCTAssertTrue(machine.requestStart(at: at(0)).decision.isStart)
        machine.apply(.startAccepted, at: at(0))

        // Backgrounding and wrist-down emit no recording event at all; the only
        // way out of `.running` is an explicit stop, a failure or a pre-emption.
        XCTAssertEqual(machine.state, .running)
        XCTAssertNil(machine.apply(.sessionRunning, at: at(10)))
        XCTAssertEqual(machine.state, .running)
        XCTAssertEqual(machine.segments.count, 1)
        XCTAssertTrue(machine.segments[0].isOpen)
    }

    /// HealthKit refuses a start while the app is in the background. Nothing was
    /// created, so a later foreground attempt is a first start, not a restart.
    func testBackgroundBlockedStartStaysRetryable() {
        var machine = WorkoutRecordingStateMachine(mode: .rallyMateManaged)
        XCTAssertTrue(machine.requestStart(at: at(0)).decision.isStart)
        machine.apply(.startBlocked(code: 14), at: at(0))

        XCTAssertEqual(machine.state, .idle)
        XCTAssertTrue(machine.segments.isEmpty)

        let (decision, _) = machine.requestStart(at: at(1))
        XCTAssertTrue(decision.isStart)
        machine.apply(.startAccepted, at: at(1))
        XCTAssertEqual(machine.segments.count, 1)
    }

    // MARK: - 7. Force quit / crash recovery

    func testRecoveredSessionContinuesTheSameSegment() {
        var machine = WorkoutRecordingStateMachine(mode: .rallyMateManaged)
        XCTAssertTrue(machine.requestStart(at: at(0)).decision.isStart)
        machine.apply(.startAccepted, at: at(0))

        // Relaunch: state and segments come back from disk.
        var relaunched = WorkoutRecordingStateMachine(mode: .rallyMateManaged)
        relaunched.restore(segments: machine.segments, state: .idle)
        relaunched.apply(.recovered(startedAt: at(0), paused: false), at: at(30))

        XCTAssertEqual(relaunched.state, .running)
        XCTAssertEqual(relaunched.segments.count, 1)
        XCTAssertEqual(relaunched.segments[0].startedAt, at(0))

        relaunched.apply(.stopRequested(.matchFinished), at: at(90))
        relaunched.apply(.sessionEnded, at: at(90))
        relaunched.apply(.finalizeSucceeded, at: at(90))
        let quality = relaunched.quality(matchStart: at(0), matchEnd: at(90))
        XCTAssertEqual(quality.recordedDuration, 90 * 60, accuracy: 1)
        XCTAssertEqual(quality.completeness, .complete)
    }

    /// The normal start path probes for a surviving session first: adopting it
    /// must complete the pending start, not be ignored as a duplicate.
    func testRecoveryDuringStartAdoptsInsteadOfCreatingASecondSession() {
        var machine = WorkoutRecordingStateMachine(mode: .rallyMateManaged)
        XCTAssertTrue(machine.requestStart(at: at(0)).decision.isStart)
        XCTAssertEqual(machine.state, .preparing)

        machine.apply(.recovered(startedAt: at(-5), paused: false), at: at(0))
        XCTAssertEqual(machine.state, .running)
        XCTAssertEqual(machine.acceptedStarts, 1)
        XCTAssertEqual(machine.segments.count, 1)
        XCTAssertEqual(machine.segments[0].startedAt, at(-5))
    }

    // MARK: - 8. Permissions

    func testDeniedAuthorizationFailsClosedWithoutRestartLoop() {
        var machine = WorkoutRecordingStateMachine(mode: .rallyMateManaged)
        XCTAssertTrue(machine.requestStart(at: at(0)).decision.isStart)
        machine.apply(.authorizationDenied, at: at(0))

        XCTAssertEqual(machine.state, .failed)
        let (decision, _) = machine.requestStart(at: at(1))
        XCTAssertEqual(decision, .rejected(.autoRestartSuppressed))
        XCTAssertEqual(
            machine.quality(matchStart: at(0), matchEnd: at(90)).completeness,
            .none
        )
    }

    func testAuthorizationRevokedMidMatchSavesWhatWasCollected() {
        var machine = WorkoutRecordingStateMachine(mode: .rallyMateManaged)
        XCTAssertTrue(machine.requestStart(at: at(0)).decision.isStart)
        machine.apply(.startAccepted, at: at(0))
        machine.apply(.sessionFailed(code: 5), at: at(40))
        machine.apply(.finalizeSucceeded, at: at(40))

        XCTAssertEqual(machine.state, .saved)
        XCTAssertEqual(machine.segments.count, 1)
        let quality = machine.quality(matchStart: at(0), matchEnd: at(90))
        XCTAssertEqual(quality.completeness, .partial)
        XCTAssertEqual(quality.recordedDuration, 40 * 60, accuracy: 1)
    }

    // MARK: - 9. Pause / resume

    func testPauseAndResumeKeepASingleSegment() {
        var machine = WorkoutRecordingStateMachine(mode: .rallyMateManaged)
        XCTAssertTrue(machine.requestStart(at: at(0)).decision.isStart)
        machine.apply(.startAccepted, at: at(0))
        machine.apply(.sessionPaused, at: at(30))
        XCTAssertEqual(machine.state, .paused)

        // A start request while paused is still a duplicate, not a new session.
        XCTAssertEqual(
            machine.requestStart(at: at(31)).decision,
            .rejected(.duplicateStartIgnored)
        )

        machine.apply(.sessionResumed, at: at(35))
        XCTAssertEqual(machine.state, .running)
        machine.apply(.stopRequested(.matchFinished), at: at(90))
        machine.apply(.sessionEnded, at: at(90))
        machine.apply(.finalizeSucceeded, at: at(90))
        XCTAssertEqual(machine.segments.count, 1)
    }

    // MARK: - 10/11/12. Finish, double tap, duplicate callbacks

    func testPausedTerminationWaitsForRunningCallbackBeforeEnding() {
        XCTAssertEqual(
            WatchWorkoutTerminationPolicy.action(for: .paused),
            .resumeAndWait
        )
        XCTAssertEqual(
            WatchWorkoutTerminationPolicy.action(for: .running),
            .end
        )
        XCTAssertEqual(
            WatchWorkoutTerminationPolicy.action(for: .stopped),
            .end
        )
        XCTAssertEqual(
            WatchWorkoutTerminationPolicy.action(for: .ended),
            .finalize
        )
    }

    func testTerminationWaitsWhileHealthKitIsStillStarting() {
        XCTAssertEqual(
            WatchWorkoutTerminationPolicy.action(for: .notStarted),
            .waitForStateChange
        )
        XCTAssertEqual(
            WatchWorkoutTerminationPolicy.action(for: .prepared),
            .waitForStateChange
        )
    }

    func testDoubleTapOnStartCreatesOneSessionOnly() {
        var machine = WorkoutRecordingStateMachine(mode: .rallyMateManaged)
        XCTAssertTrue(machine.requestStart(at: at(0)).decision.isStart)
        // The second tap arrives before HealthKit confirms the first session.
        XCTAssertEqual(
            machine.requestStart(at: at(0)).decision,
            .rejected(.duplicateStartIgnored)
        )
        machine.apply(.startAccepted, at: at(0))
        XCTAssertEqual(machine.acceptedStarts, 1)
        XCTAssertEqual(machine.segments.count, 1)
    }

    func testDuplicateDelegateCallbacksAreIdempotent() {
        var machine = WorkoutRecordingStateMachine(mode: .rallyMateManaged)
        XCTAssertTrue(machine.requestStart(at: at(0)).decision.isStart)
        machine.apply(.startAccepted, at: at(0))

        machine.apply(.stopRequested(.matchFinished), at: at(90))
        XCTAssertNotNil(machine.apply(.sessionEnded, at: at(90)))
        // watchOS can redeliver the transition after the app resumes.
        XCTAssertNil(machine.apply(.sessionEnded, at: at(90)))
        XCTAssertNotNil(machine.apply(.finalizeSucceeded, at: at(90)))
        XCTAssertNil(machine.apply(.finalizeSucceeded, at: at(90)))
        XCTAssertNil(machine.apply(.finalizeFailed(code: 3), at: at(90)))

        XCTAssertEqual(machine.state, .saved)
        XCTAssertEqual(machine.segments.count, 1)
        XCTAssertEqual(
            machine.quality(matchStart: at(0), matchEnd: at(90)).recordedDuration,
            90 * 60,
            accuracy: 1
        )
    }

    func testFinishAfterSaveDoesNotReopenTheRecording() {
        var machine = WorkoutRecordingStateMachine(mode: .rallyMateManaged)
        XCTAssertTrue(machine.requestStart(at: at(0)).decision.isStart)
        machine.apply(.startAccepted, at: at(0))
        machine.apply(.stopRequested(.matchFinished), at: at(90))
        machine.apply(.sessionEnded, at: at(90))
        machine.apply(.finalizeSucceeded, at: at(90))

        XCTAssertNil(machine.apply(.stopRequested(.matchFinished), at: at(91)))
        XCTAssertEqual(
            machine.requestStart(at: at(91)).decision,
            .rejected(.autoRestartSuppressed)
        )
        XCTAssertEqual(machine.segments.count, 1)
    }

    // MARK: - Quality reporting honesty

    func testShortSegmentOnLongMatchIsReportedPartial() {
        var machine = WorkoutRecordingStateMachine(mode: .rallyMateManaged)
        machine.restore(
            segments: [
                WatchWorkoutSegment(startedAt: at(0), endedAt: at(5), saved: true),
            ],
            state: .saved
        )
        let quality = machine.quality(matchStart: at(0), matchEnd: at(90))
        XCTAssertEqual(quality.completeness, .partial)
        XCTAssertTrue(quality.detail.contains("5 min"))
        XCTAssertTrue(quality.detail.contains("90 min"))
    }

    func testRunningMatchIsReportedPending() {
        var machine = WorkoutRecordingStateMachine(mode: .rallyMateManaged)
        XCTAssertTrue(machine.requestStart(at: at(0)).decision.isStart)
        machine.apply(.startAccepted, at: at(0))
        let quality = machine.quality(
            matchStart: at(0),
            matchEnd: nil,
            now: at(20)
        )
        XCTAssertEqual(quality.completeness, .pending)
    }

    // MARK: - Logging

    func testTransitionLogCarriesStatesReasonAndErrorWithoutIdentifiers() {
        var machine = WorkoutRecordingStateMachine(mode: .rallyMateManaged)
        _ = machine.requestStart(at: at(0))
        machine.apply(.startAccepted, at: at(0))
        guard let transition = machine.apply(.preempted(code: 8), at: at(5)) else {
            return XCTFail("expected a transition")
        }
        let line = WatchWorkoutLog.format(
            transition,
            matchId: "mt_aw_secret-user-match"
        )

        XCTAssertTrue(line.contains("running->finalizing"))
        XCTAssertTrue(line.contains("PREEMPTED_BY_OTHER_APP"))
        XCTAssertTrue(line.contains("hk=8"))
        XCTAssertFalse(line.contains("secret-user-match"))
    }
}
