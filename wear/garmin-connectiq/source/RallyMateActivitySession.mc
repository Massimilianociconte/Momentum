import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

const RM_ACTIVITY_OWNERSHIP_KEY = "rallymate_activity_owner_v1";
const RM_RECORDING_MODE_KEY = "rallymate_recording_mode_v1";
const RM_ACTIVITY_START_TOLERANCE_SECONDS = 10;

// Who owns the FIT recording for a match. A Connect IQ device app may own one
// recording session at a time, so the user picks the owner and Momentum never
// competes for it.
const RM_MODE_RALLYMATE = "RALLYMATE_MANAGED";
const RM_MODE_EXTERNAL = "EXTERNAL_MANAGED";
const RM_MODE_DISABLED = "DISABLED";

const RM_STATE_IDLE = "IDLE";
const RM_STATE_OWNED = "OWNED";
const RM_STATE_SAVED = "SAVED";
const RM_STATE_EXTERNAL = "EXTERNAL";
const RM_STATE_FAILED = "FAILED";

// Start decisions. Only START may create a session.
const RM_START_ALLOWED = "START";
const RM_START_DUPLICATE = "DUPLICATE_START_IGNORED";
const RM_START_SUPPRESSED = "AUTO_RESTART_SUPPRESSED";
const RM_START_EXTERNAL = "USER_CHOICE_EXTERNAL";
const RM_START_DISABLED = "USER_CHOICE_DISABLED";

class RallyMateRecordingPolicy {
    public static function normalizeMode(mode) {
        if (mode != null
                && (mode.equals(RM_MODE_EXTERNAL) || mode.equals(RM_MODE_DISABLED))) {
            return mode;
        }
        return RM_MODE_RALLYMATE;
    }

    public static function ownsSession(state) {
        return state != null && state.equals(RM_STATE_OWNED);
    }

    public static function isTerminal(state) {
        return state != null
            && (state.equals(RM_STATE_SAVED)
                || state.equals(RM_STATE_EXTERNAL)
                || state.equals(RM_STATE_FAILED));
    }

    // Single gate: duplicates and terminal states are refused, and a recording
    // that already ended is never restarted without an explicit user request.
    public static function startDecision(mode, state, userInitiated) {
        var normalized = normalizeMode(mode);
        if (normalized.equals(RM_MODE_DISABLED)) {
            return RM_START_DISABLED;
        }
        if (normalized.equals(RM_MODE_EXTERNAL)) {
            return RM_START_EXTERNAL;
        }
        if (ownsSession(state)) {
            return RM_START_DUPLICATE;
        }
        if (isTerminal(state) && userInitiated != true) {
            return RM_START_SUPPRESSED;
        }
        return RM_START_ALLOWED;
    }
}

class RallyMateActivityPolicy {
    public static function isIdle(timerState) {
        return timerState == null || timerState == Activity.TIMER_STATE_OFF;
    }

    // Garmin uses :suspend to distinguish a system suspension, whose activity
    // session may be resumed later, from a real application exit. Only a real
    // exit is allowed to finalize the FIT recording.
    public static function shouldFinalizeOnStop(state) {
        return !(state instanceof Dictionary && state[:suspend] == true);
    }

    public static function canRecover(owner, matchId, currentStartSeconds) {
        if (!(owner instanceof Dictionary)
                || matchId == null
                || owner["matchId"] == null
                || !owner["matchId"].equals(matchId)
                || !(owner["startSeconds"] instanceof Number)
                || !(currentStartSeconds instanceof Number)) {
            return false;
        }
        return (owner["startSeconds"] - currentStartSeconds).abs()
            <= RM_ACTIVITY_START_TOLERANCE_SECONDS;
    }
}

// A Connect IQ device app may own one FIT recording session. RallyMate never
// adopts or closes a session it cannot prove it created for the active match.
class RallyMateActivitySession {
    private var _session = null;
    private var _status = "IDLE";
    private var _owner = null;
    private var _mode = RM_MODE_RALLYMATE;

    public function initialize() {
        _owner = Storage.getValue(RM_ACTIVITY_OWNERSHIP_KEY);
        _mode = RallyMateRecordingPolicy.normalizeMode(
            Storage.getValue(RM_RECORDING_MODE_KEY)
        );
        if (_owner instanceof Dictionary && _owner["mode"] != null) {
            _mode = RallyMateRecordingPolicy.normalizeMode(_owner["mode"]);
        }
        if (_mode.equals(RM_MODE_EXTERNAL)) {
            _status = RM_STATE_EXTERNAL;
        } else if (_mode.equals(RM_MODE_DISABLED)) {
            _status = "DISABLED";
        }
    }

    public function status() {
        return _status;
    }

    public function recordingMode() {
        return _mode;
    }

    // Preference for the next match; a running match keeps its own owner.
    public function setRecordingMode(mode) {
        _mode = RallyMateRecordingPolicy.normalizeMode(mode);
        Storage.setValue(RM_RECORDING_MODE_KEY, _mode);
        if (_session == null) {
            if (_mode.equals(RM_MODE_EXTERNAL)) {
                _status = RM_STATE_EXTERNAL;
            } else if (_mode.equals(RM_MODE_DISABLED)) {
                _status = "DISABLED";
            } else {
                _status = RM_STATE_IDLE;
            }
        }
        return _mode;
    }

    private function ownerState() {
        if (_session != null) {
            return RM_STATE_OWNED;
        }
        if (_owner instanceof Dictionary && _owner["state"] != null) {
            return _owner["state"];
        }
        return RM_STATE_IDLE;
    }

    private function rememberState(matchId, state) {
        var record = _owner instanceof Dictionary ? _owner : {};
        record["version"] = 1;
        record["matchId"] = matchId;
        record["mode"] = _mode;
        record["state"] = state;
        _owner = record;
        Storage.setValue(RM_ACTIVITY_OWNERSHIP_KEY, _owner);
    }

    public function ownsMatch(matchId) {
        return _owner instanceof Dictionary
            && matchId != null
            && _owner["matchId"] != null
            && _owner["matchId"].equals(matchId);
    }

    public function inspectExternalActivity() {
        if (_session != null) {
            _status = "OWNED";
            return _status;
        }
        var info = safeActivityInfo();
        _status = info != null && !RallyMateActivityPolicy.isIdle(info.timerState)
            ? "EXTERNAL"
            : "IDLE";
        return _status;
    }

    public function restoreForMatch(model) {
        if (model == null || !ownsMatch(model.matchId())) {
            inspectExternalActivity();
            return false;
        }

        var info = safeActivityInfo();
        if (info == null || RallyMateActivityPolicy.isIdle(info.timerState)) {
            if (model.score()["complete"] == true) {
                clearOwnership();
                _status = "IDLE";
                return false;
            }
            // startForMatch refuses a terminal state without user consent, so a
            // recording that already ended is not silently reopened here.
            return startForMatch(model.matchId());
        }

        var currentStart = momentSeconds(info.startTime);
        if (!RallyMateActivityPolicy.canRecover(_owner, model.matchId(), currentStart)) {
            // A different activity now owns the recorder. Never obtain the
            // singleton Session object because doing so would return that
            // external session.
            clearOwnership();
            _status = "EXTERNAL";
            return false;
        }

        _session = createPadelSession();
        if (_session == null) {
            _status = "UNAVAILABLE";
            return false;
        }
        _status = "OWNED";
        var score = model.score();
        if (score["complete"] == true) {
            return completeForMatch(model.matchId());
        }
        if (score["paused"] == true && _session.isRecording()) {
            return _session.stop();
        }
        if (score["paused"] != true && !_session.isRecording()) {
            return _session.start();
        }
        return true;
    }

    public function startForMatch(matchId) {
        return startForMatchWithConsent(matchId, false);
    }

    // The only entry point allowed to create a FIT session.
    public function startForMatchWithConsent(matchId, userInitiated) {
        if (matchId == null) {
            return false;
        }
        if (!ownsMatch(matchId)) {
            // A new match starts from a clean ownership record.
            clearOwnership();
        }
        if (_session != null && ownsMatch(matchId)) {
            _status = RM_STATE_OWNED;
            return _session.isRecording() || _session.start();
        }

        var decision = RallyMateRecordingPolicy.startDecision(
            _mode,
            ownerState(),
            userInitiated
        );
        if (decision.equals(RM_START_DISABLED)) {
            _status = "DISABLED";
            rememberState(matchId, RM_STATE_IDLE);
            return false;
        }
        if (decision.equals(RM_START_EXTERNAL)) {
            _status = RM_STATE_EXTERNAL;
            rememberState(matchId, RM_STATE_EXTERNAL);
            return false;
        }
        if (!decision.equals(RM_START_ALLOWED)) {
            // Duplicate request or an automatic restart after an interruption.
            return false;
        }

        var info = safeActivityInfo();
        if (info != null && !RallyMateActivityPolicy.isIdle(info.timerState)) {
            // Expected condition: another activity already owns the recorder.
            _status = RM_STATE_EXTERNAL;
            rememberState(matchId, RM_STATE_EXTERNAL);
            notifyExternalActivity();
            return false;
        }

        _session = createPadelSession();
        if (_session == null || !_session.start()) {
            _session = null;
            _status = "UNAVAILABLE";
            rememberState(matchId, RM_STATE_FAILED);
            return false;
        }

        var startedInfo = safeActivityInfo();
        var startedSeconds = startedInfo == null
            ? Time.now().value()
            : momentSeconds(startedInfo.startTime);
        if (!(startedSeconds instanceof Number)) {
            startedSeconds = Time.now().value();
        }
        _owner = {
            "version" => 1,
            "matchId" => matchId,
            "mode" => _mode,
            "state" => RM_STATE_OWNED,
            "startSeconds" => startedSeconds
        };
        Storage.setValue(RM_ACTIVITY_OWNERSHIP_KEY, _owner);
        _status = RM_STATE_OWNED;
        return true;
    }

    public function pauseForMatch(matchId) {
        if (!ensureOwned(matchId)) {
            return false;
        }
        return !_session.isRecording() || _session.stop();
    }

    public function resumeForMatch(matchId) {
        if (!ensureOwned(matchId)) {
            return false;
        }
        return _session.isRecording() || _session.start();
    }

    public function completeForMatch(matchId) {
        return finalizeOwnedSession(matchId);
    }

    // A user-driven app exit ends only the FIT recording. The event-sourced
    // match remains persisted and resumable, but reopening the app cannot
    // silently restart the already-saved recording.
    public function closeForAppExit(matchId) {
        return finalizeOwnedSession(matchId);
    }

    private function finalizeOwnedSession(matchId) {
        if (!ensureOwned(matchId)) {
            return false;
        }
        if (_session.isRecording() && !_session.stop()) {
            _status = "SAVE_PENDING";
            return false;
        }
        if (!_session.save()) {
            _status = "SAVE_PENDING";
            return false;
        }
        _session = null;
        // Terminal for this match: keep the record so nothing reopens it, and
        // let a brand-new match reset it in startForMatchWithConsent.
        rememberState(matchId, RM_STATE_SAVED);
        _status = RM_STATE_SAVED;
        return true;
    }

    private function ensureOwned(matchId) {
        if (_session != null && ownsMatch(matchId)) {
            return true;
        }
        if (!ownsMatch(matchId)) {
            return false;
        }
        var info = safeActivityInfo();
        if (info == null || RallyMateActivityPolicy.isIdle(info.timerState)) {
            return false;
        }
        if (!RallyMateActivityPolicy.canRecover(
                _owner,
                matchId,
                momentSeconds(info.startTime)
            )) {
            clearOwnership();
            _status = "EXTERNAL";
            return false;
        }
        _session = createPadelSession();
        return _session != null;
    }

    private function createPadelSession() {
        if (!(ActivityRecording has :createSession)) {
            return null;
        }
        var options = {
            :name => "Momentum",
            :sport => ActivityRecording.SPORT_TENNIS,
            :subSport => ActivityRecording.SUB_SPORT_GENERIC
        };
        if (ActivityRecording has :SUB_SPORT_PADEL) {
            options[:subSport] = ActivityRecording.SUB_SPORT_PADEL;
        }
        try {
            return ActivityRecording.createSession(options);
        } catch (error) {
            System.println("RallyMate activity session unavailable: " + error.toString());
            return null;
        }
    }

    private function safeActivityInfo() {
        try {
            return Activity.getActivityInfo();
        } catch (error) {
            return null;
        }
    }

    private function momentSeconds(moment) {
        return moment == null ? null : moment.value();
    }

    private function clearOwnership() {
        _owner = null;
        Storage.deleteValue(RM_ACTIVITY_OWNERSHIP_KEY);
    }

    private function notifyExternalActivity() {
        if (WatchUi has :showToast) {
            WatchUi.showToast(Rez.Strings.ExternalActivityScoringOnly, null);
        }
    }
}
