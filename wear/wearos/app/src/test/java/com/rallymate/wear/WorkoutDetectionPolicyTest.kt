package com.rallymate.wear

import androidx.health.services.client.data.ExerciseTrackedStatus
import androidx.health.services.client.data.ExerciseType
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WorkoutDetectionPolicyTest {
    private val ask = WorkoutDetectionPreferences(
        mode = WorkoutDetectionMode.ASK,
        racketSportsOnly = true,
    )

    @Test
    fun `external racket workout is eligible`() {
        assertTrue(
            eligible(
                preferences = ask,
                status = ExerciseTrackedStatus.OTHER_APP_IN_PROGRESS,
                type = ExerciseType.TENNIS,
            )
        )
    }

    @Test
    fun `own and absent exercises never prompt`() {
        assertFalse(
            eligible(
                preferences = ask,
                status = ExerciseTrackedStatus.OWNED_EXERCISE_IN_PROGRESS,
                type = ExerciseType.TENNIS,
            )
        )
        assertFalse(
            eligible(
                preferences = ask,
                status = ExerciseTrackedStatus.NO_EXERCISE_IN_PROGRESS,
                type = ExerciseType.TENNIS,
            )
        )
    }

    @Test
    fun `racket filter rejects unrelated workouts`() {
        assertFalse(
            eligible(
                preferences = ask,
                status = ExerciseTrackedStatus.OTHER_APP_IN_PROGRESS,
                type = ExerciseType.RUNNING,
            )
        )
        assertTrue(
            eligible(
                preferences = ask.copy(racketSportsOnly = false),
                status = ExerciseTrackedStatus.OTHER_APP_IN_PROGRESS,
                type = ExerciseType.RUNNING,
            )
        )
    }

    @Test
    fun `disabled ignored and active match states suppress prompts`() {
        assertFalse(
            eligible(
                preferences = WorkoutDetectionPreferences(),
                status = ExerciseTrackedStatus.OTHER_APP_IN_PROGRESS,
                type = ExerciseType.SQUASH,
            )
        )
        assertFalse(
            eligible(
                preferences = ask,
                status = ExerciseTrackedStatus.OTHER_APP_IN_PROGRESS,
                type = ExerciseType.SQUASH,
                ignored = "77:123",
            )
        )
        assertFalse(
            eligible(
                preferences = ask,
                status = ExerciseTrackedStatus.OTHER_APP_IN_PROGRESS,
                type = ExerciseType.SQUASH,
                activeMatch = true,
            )
        )
    }

    private fun eligible(
        preferences: WorkoutDetectionPreferences,
        status: Int,
        type: ExerciseType,
        ignored: String? = null,
        activeMatch: Boolean = false,
    ): Boolean = WorkoutDetectionPolicy.shouldPrompt(
        preferences = preferences,
        trackedStatus = status,
        exerciseTypeName = type.name,
        fingerprint = "77:123",
        ignoredFingerprint = ignored,
        activeRallyMateMatch = activeMatch,
    )
}
