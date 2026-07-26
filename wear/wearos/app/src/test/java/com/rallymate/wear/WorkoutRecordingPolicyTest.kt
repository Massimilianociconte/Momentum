package com.rallymate.wear

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Wear OS mirror of the watchOS ownership matrix: one owner per match, no
 * automatic restart after another app takes the exercise, honest reporting.
 */
class WorkoutRecordingPolicyTest {

    private val start = 1_700_000_000_000L
    private fun at(minutes: Double) = start + (minutes * 60_000).toLong()

    @Test
    fun `ninety minute match produces one saved segment`() {
        val machine = WearRecordingStateMachine(WearHealthRecordingMode.RALLYMATE_MANAGED)
        assertTrue(machine.requestStart(at(0.0)).decision is WearRecordingStateMachine.StartDecision.Start)
        machine.onExerciseStarted(at(0.0))
        machine.onStopRequested(at(90.0), WearRecordingReason.MATCH_FINISHED)
        machine.onExerciseEnded(at(90.0), saved = true)

        assertEquals(WearRecordingState.SAVED, machine.state)
        assertEquals(1, machine.acceptedStarts)
        assertEquals(1, machine.segments.size)
        assertTrue(machine.segments[0].saved)

        val quality = machine.quality(at(0.0), at(90.0), at(90.0))
        assertEquals(WearRecordingCompleteness.COMPLETE, quality.completeness)
        assertEquals(90 * 60_000L, quality.recordedDurationMs)
    }

    @Test
    fun `scoring taps never open a second exercise`() {
        val machine = WearRecordingStateMachine()
        machine.requestStart(at(0.0))
        machine.onExerciseStarted(at(0.0))

        for (minute in 1..89) {
            val result = machine.requestStart(at(minute.toDouble()))
            assertEquals(
                WearRecordingStateMachine.StartDecision.Rejected(
                    WearRecordingReason.DUPLICATE_START_IGNORED
                ),
                result.decision,
            )
        }
        assertEquals(1, machine.acceptedStarts)
        assertEquals(1, machine.segments.size)
    }

    @Test
    fun `external mode never opens an exercise`() {
        val machine = WearRecordingStateMachine(WearHealthRecordingMode.EXTERNAL_MANAGED)
        val result = machine.requestStart(at(0.0))
        assertEquals(
            WearRecordingStateMachine.StartDecision.Rejected(
                WearRecordingReason.USER_CHOICE_EXTERNAL
            ),
            result.decision,
        )
        assertEquals(0, machine.acceptedStarts)
        assertEquals(WearRecordingState.EXTERNAL_OWNED, machine.state)
        assertEquals(
            WearRecordingCompleteness.EXTERNAL,
            machine.quality(at(0.0), at(90.0), at(90.0)).completeness,
        )
    }

    @Test
    fun `disabled mode records nothing`() {
        val machine = WearRecordingStateMachine(WearHealthRecordingMode.DISABLED)
        machine.requestStart(at(0.0))
        assertEquals(WearRecordingState.DISABLED, machine.state)
        assertEquals(0, machine.acceptedStarts)
        assertEquals(
            WearRecordingCompleteness.NONE,
            machine.quality(at(0.0), at(90.0), at(90.0)).completeness,
        )
    }

    @Test
    fun `other app in progress at start suppresses automatic retries`() {
        val machine = WearRecordingStateMachine()
        machine.requestStart(at(0.0))
        machine.onOwnedByOtherApp(at(0.0))

        assertEquals(WearRecordingState.EXTERNAL_OWNED, machine.state)
        for (minute in 1..30) {
            val result = machine.requestStart(at(minute.toDouble()))
            assertEquals(
                WearRecordingStateMachine.StartDecision.Rejected(
                    WearRecordingReason.AUTO_RESTART_SUPPRESSED
                ),
                result.decision,
            )
        }
        assertEquals(1, machine.acceptedStarts)
        assertTrue(machine.segments.isEmpty())
    }

    @Test
    fun `ownership lost mid match saves a partial segment without restart`() {
        val machine = WearRecordingStateMachine()
        machine.requestStart(at(0.0))
        machine.onExerciseStarted(at(0.0))
        machine.onOwnedByOtherApp(at(5.0))

        assertEquals(WearRecordingState.EXTERNAL_OWNED, machine.state)
        assertEquals(1, machine.segments.size)
        assertTrue(machine.segments[0].saved)

        val quality = machine.quality(at(0.0), at(90.0), at(90.0))
        assertEquals(WearRecordingCompleteness.PARTIAL, quality.completeness)
        assertTrue(quality.isPartial)
        assertEquals(5 * 60_000L, quality.recordedDurationMs)
        assertTrue(quality.coverage < 0.1)
    }

    @Test
    fun `explicit user restart opens a second segment only`() {
        val machine = WearRecordingStateMachine()
        machine.requestStart(at(0.0))
        machine.onExerciseStarted(at(0.0))
        machine.onOwnedByOtherApp(at(5.0))

        val result = machine.requestStart(at(20.0), userInitiated = true)
        assertTrue(result.decision is WearRecordingStateMachine.StartDecision.Start)
        machine.onExerciseStarted(at(20.0))
        machine.onStopRequested(at(90.0), WearRecordingReason.MATCH_FINISHED)
        machine.onExerciseEnded(at(90.0), saved = true)

        assertEquals(2, machine.segments.size)
        val quality = machine.quality(at(0.0), at(90.0), at(90.0))
        assertEquals(WearRecordingCompleteness.PARTIAL, quality.completeness)
        assertEquals(75 * 60_000L, quality.recordedDurationMs)
    }

    @Test
    fun `overlapping segments are merged not summed`() {
        val machine = WearRecordingStateMachine()
        machine.restore(
            listOf(
                WearWorkoutSegment(at(0.0), at(30.0), saved = true),
                WearWorkoutSegment(at(20.0), at(50.0), saved = true),
            ),
            WearRecordingState.SAVED,
        )
        assertEquals(
            50 * 60_000L,
            machine.quality(at(0.0), at(90.0), at(90.0)).recordedDurationMs,
        )
    }

    @Test
    fun `double tap opens one exercise`() {
        val machine = WearRecordingStateMachine()
        assertTrue(machine.requestStart(at(0.0)).decision is WearRecordingStateMachine.StartDecision.Start)
        assertEquals(
            WearRecordingStateMachine.StartDecision.Rejected(
                WearRecordingReason.DUPLICATE_START_IGNORED
            ),
            machine.requestStart(at(0.0)).decision,
        )
        machine.onExerciseStarted(at(0.0))
        assertEquals(1, machine.acceptedStarts)
        assertEquals(1, machine.segments.size)
    }

    @Test
    fun `duplicate end callbacks are idempotent`() {
        val machine = WearRecordingStateMachine()
        machine.requestStart(at(0.0))
        machine.onExerciseStarted(at(0.0))
        machine.onStopRequested(at(90.0), WearRecordingReason.MATCH_FINISHED)

        assertNotNull(machine.onExerciseEnded(at(90.0), saved = true))
        assertNull(machine.onExerciseEnded(at(90.0), saved = true))
        assertEquals(1, machine.segments.size)
        assertEquals(
            90 * 60_000L,
            machine.quality(at(0.0), at(90.0), at(90.0)).recordedDurationMs,
        )
    }

    @Test
    fun `pause and resume keep a single segment`() {
        val machine = WearRecordingStateMachine()
        machine.requestStart(at(0.0))
        machine.onExerciseStarted(at(0.0))
        machine.onPaused(at(30.0))
        assertEquals(WearRecordingState.PAUSED, machine.state)
        assertEquals(
            WearRecordingStateMachine.StartDecision.Rejected(
                WearRecordingReason.DUPLICATE_START_IGNORED
            ),
            machine.requestStart(at(31.0)).decision,
        )
        machine.onResumed(at(35.0))
        machine.onStopRequested(at(90.0), WearRecordingReason.MATCH_FINISHED)
        machine.onExerciseEnded(at(90.0), saved = true)
        assertEquals(1, machine.segments.size)
    }

    @Test
    fun `recovered exercise continues the same segment after force quit`() {
        val machine = WearRecordingStateMachine()
        machine.requestStart(at(0.0))
        machine.onExerciseStarted(at(0.0))

        val relaunched = WearRecordingStateMachine()
        relaunched.restore(machine.segments, WearRecordingState.IDLE)
        relaunched.onRecovered(at(0.0), at(30.0), paused = false)

        assertEquals(WearRecordingState.RUNNING, relaunched.state)
        assertEquals(1, relaunched.segments.size)
        relaunched.onStopRequested(at(90.0), WearRecordingReason.MATCH_FINISHED)
        relaunched.onExerciseEnded(at(90.0), saved = true)
        assertEquals(
            WearRecordingCompleteness.COMPLETE,
            relaunched.quality(at(0.0), at(90.0), at(90.0)).completeness,
        )
    }

    @Test
    fun `permission denied fails closed without retry loop`() {
        val machine = WearRecordingStateMachine()
        machine.requestStart(at(0.0))
        machine.onFailure(at(0.0), WearRecordingReason.PERMISSION_DENIED)

        assertEquals(WearRecordingState.FAILED, machine.state)
        assertEquals(
            WearRecordingStateMachine.StartDecision.Rejected(
                WearRecordingReason.AUTO_RESTART_SUPPRESSED
            ),
            machine.requestStart(at(1.0)).decision,
        )
    }

    @Test
    fun `segments survive encoding round trip`() {
        val segment = WearWorkoutSegment(at(0.0), at(12.0), saved = true, endReason = "SESSION_ENDED")
        val decoded = WearWorkoutSegment.decode(segment.encode())
        assertEquals(segment, decoded)
    }

    @Test
    fun `log line carries states reason and error without identifiers`() {
        val machine = WearRecordingStateMachine()
        machine.requestStart(at(0.0))
        machine.onExerciseStarted(at(0.0))
        val transition = machine.onOwnedByOtherApp(at(5.0))
        assertNotNull(transition)
        val line = transition!!.logLine(wearMatchToken("mt_w_secret-user-match"))

        assertTrue(line.contains("running->externalOwned"))
        assertTrue(line.contains("OWNED_BY_OTHER_APP"))
        assertFalse(line.contains("secret-user-match"))
    }
}
