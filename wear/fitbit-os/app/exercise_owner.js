import { me as appbit } from "appbit";
import exercise from "exercise";

/**
 * Thin, defensive wrapper over the Fitbit OS exercise API.
 *
 * Fitbit OS tracks one exercise at a time, so RallyMate starts one only when
 * nothing else owns it, and never retries in a loop. Every call is feature
 * detected and guarded: scoring must keep working on devices or firmware where
 * the API or the `access_exercise` permission is unavailable.
 */

// Fitbit OS has no padel exercise type; tennis is the documented racket sport.
const EXERCISE_TYPE = "tennis";

function available() {
  return (
    typeof exercise === "object" &&
    exercise !== null &&
    typeof exercise.start === "function" &&
    appbit.permissions.granted("access_exercise")
  );
}

/** True when an exercise is already running, whoever owns it. */
export function exerciseOwnedByOtherApp() {
  if (!available()) return false;
  return exercise.state === "started" || exercise.state === "paused";
}

/**
 * @returns {"started"|"other_app"|"unavailable"|"failed"}
 */
export function startExercise() {
  if (!available()) return "unavailable";
  if (exerciseOwnedByOtherApp()) return "other_app";
  try {
    exercise.start(EXERCISE_TYPE, { gps: false });
  } catch (error) {
    // A concurrent exercise is the documented failure here; anything else is
    // reported as a plain failure so nothing retries blindly.
    return exerciseOwnedByOtherApp() ? "other_app" : "failed";
  }
  return exercise.state === "started" ? "started" : "failed";
}

/** @returns {boolean} true when the exercise was stopped (and thus saved). */
export function stopExercise() {
  if (!available()) return false;
  if (exercise.state !== "started" && exercise.state !== "paused") return false;
  try {
    exercise.stop();
  } catch (error) {
    return false;
  }
  return true;
}

export function pauseExercise() {
  if (!available() || exercise.state !== "started") return false;
  try {
    exercise.pause();
  } catch (error) {
    return false;
  }
  return true;
}

export function resumeExercise() {
  if (!available() || exercise.state !== "paused") return false;
  try {
    exercise.resume();
  } catch (error) {
    return false;
  }
  return true;
}
