import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;

const RM_STATE_KEY = "rallymate_match_v1";
const RM_MAX_EVENTS = 500;
const RM_MAX_BATCH = 20;

class RallyMateScoreEngine {
    public static function defaultFormat() {
        return {
            "id" => "ADV_BO3",
            "name" => "Vantaggi - meglio di 3",
            "setsToWin" => 2,
            "gamesPerSet" => 6,
            "goldenPoint" => false,
            "tieBreakAtGamesAll" => true,
            "tieBreakPoints" => 7,
            "superTieBreakDecider" => false,
            "superTieBreakPoints" => 10,
            "freePlay" => false
        };
    }

    public static function normalizedFormat(input) {
        var result = RallyMateScoreEngine.defaultFormat();
        if (!(input instanceof Dictionary)) {
            return result;
        }

        if (input["id"] instanceof String) {
            result["id"] = input["id"];
        }
        if (input["name"] instanceof String) {
            result["name"] = input["name"];
        }
        var numberKeys = [
            "setsToWin",
            "gamesPerSet",
            "tieBreakPoints",
            "superTieBreakPoints"
        ];
        for (var i = 0; i < numberKeys.size(); i += 1) {
            var key = numberKeys[i];
            var value = input[key];
            if (value instanceof Number && value > 0 && value <= 20) {
                result[key] = value;
            }
        }
        var booleanKeys = [
            "goldenPoint",
            "tieBreakAtGamesAll",
            "superTieBreakDecider",
            "freePlay"
        ];
        for (var j = 0; j < booleanKeys.size(); j += 1) {
            var booleanKey = booleanKeys[j];
            if (input[booleanKey] instanceof Boolean) {
                result[booleanKey] = input[booleanKey];
            }
        }
        return result;
    }

    public static function preset(id) {
        var format = RallyMateScoreEngine.defaultFormat();
        if (id != null && id.equals("GOLDEN_BO3")) {
            format["id"] = "GOLDEN_BO3";
            format["name"] = "Golden point - meglio di 3";
            format["goldenPoint"] = true;
        } else if (id != null && id.equals("SINGLE_SET")) {
            format["id"] = "SINGLE_SET";
            format["name"] = "Partita secca";
            format["setsToWin"] = 1;
        } else if (id != null && id.equals("TRAINING")) {
            format["id"] = "TRAINING";
            format["name"] = "Allenamento libero";
            format["freePlay"] = true;
        }
        return format;
    }

    public static function replay(events, format) {
        var resolution = RallyMateScoreEngine.resolveEventMasks(events);
        var undone = resolution["cancelled"];
        var ignored = resolution["ignored"];

        var state = {
            "started" => false,
            "paused" => false,
            "pointsA" => 0,
            "pointsB" => 0,
            "gamesA" => 0,
            "gamesB" => 0,
            "setsA" => 0,
            "setsB" => 0,
            "tiebreak" => false,
            "superTiebreak" => false,
            "complete" => false,
            "display" => "0 - 0",
            "situation" => "",
            "setsDisplay" => "SET 0-0  GAME 0-0"
        };

        for (var j = 0; j < events.size(); j += 1) {
            if (ignored.hasKey(j)) {
                continue;
            }
            var pointEvent = events[j];
            var type = pointEvent["type"];
            if (type != null && type.equals("MATCH_STARTED")) {
                state["started"] = true;
                continue;
            }
            if (type != null && type.equals("MATCH_PAUSED")) {
                if (state["complete"] != true) {
                    state["paused"] = true;
                }
                continue;
            }
            if (type != null && type.equals("MATCH_RESUMED")) {
                if (state["complete"] != true && state["paused"] == true) {
                    state["paused"] = false;
                }
                continue;
            }
            if (type != null
                    && type.equals("MATCH_COMPLETED")
                    && pointEvent["sourceMethod"] != null
                    && pointEvent["sourceMethod"].equals("MANUAL_EDIT")) {
                state["complete"] = true;
                state["paused"] = false;
                continue;
            }
            if (type == null
                    || (!type.equals("POINT_TEAM_A") && !type.equals("POINT_TEAM_B"))
                    || undone.hasKey(pointEvent["id"])) {
                continue;
            }
            if (state["complete"] == true || state["paused"] == true) {
                continue;
            }
            RallyMateScoreEngine.applyPoint(state, type.equals("POINT_TEAM_A"), format);
        }

        RallyMateScoreEngine.formatState(state, format);
        return state;
    }

    // Resolve UNDO and lifecycle-invalid log entries before replay. Paused
    // point/undo entries remain in the journal for sync but never affect score.
    public static function resolveEventMasks(events) {
        var cancelled = {};
        var ignored = {};
        var lifecycle = "created";
        var manuallyCompleted = false;
        for (var i = 0; i < events.size(); i += 1) {
            var event = events[i];
            var eventType = event["type"];
            if (eventType == null) {
                continue;
            }
            if (eventType.equals("MATCH_STARTED")) {
                if (lifecycle.equals("created")) {
                    lifecycle = "in_progress";
                }
            } else if (eventType.equals("MATCH_PAUSED")) {
                if (lifecycle.equals("in_progress")) {
                    lifecycle = "paused";
                }
            } else if (eventType.equals("MATCH_RESUMED")) {
                if (lifecycle.equals("paused")) {
                    lifecycle = "in_progress";
                }
            } else if (eventType.equals("POINT_TEAM_A") || eventType.equals("POINT_TEAM_B")) {
                if (lifecycle.equals("paused") || lifecycle.equals("completed")) {
                    ignored[i] = true;
                } else if (lifecycle.equals("created")) {
                    lifecycle = "in_progress";
                }
            } else if (eventType.equals("MATCH_COMPLETED")) {
                lifecycle = "completed";
                if (event["sourceMethod"] != null
                        && event["sourceMethod"].equals("MANUAL_EDIT")) {
                    manuallyCompleted = true;
                }
            } else if (eventType.equals("UNDO")) {
                if (lifecycle.equals("paused")) {
                    ignored[i] = true;
                } else if (event["target"] != null) {
                    cancelled[event["target"]] = true;
                    // Derived completion belongs to the point that produced it;
                    // undo keeps reopening that automatic completion.
                    if (lifecycle.equals("completed") && !manuallyCompleted) {
                        lifecycle = "in_progress";
                    }
                }
            }
        }
        return {"cancelled" => cancelled, "ignored" => ignored};
    }

    // Ultimo punto annullabile del journal. `assignedTeam` (Duo Mode) limita la
    // scelta ai punti del proprio team. Statica e pubblica perché è la stessa
    // regola usata dal modello a runtime e dal test di conformità sui vettori
    // condivisi: una seconda implementazione nel test proverebbe solo se stessa.
    public static function lastUndoableEventIdIn(events, assignedTeam) {
        var resolution = RallyMateScoreEngine.resolveEventMasks(events);
        var undone = resolution["cancelled"];
        var ignored = resolution["ignored"];
        for (var j = events.size() - 1; j >= 0; j -= 1) {
            var candidate = events[j];
            var candidateType = candidate["type"];
            if (candidateType != null
                    && (candidateType.equals("POINT_TEAM_A") || candidateType.equals("POINT_TEAM_B"))
                    && (assignedTeam == null || candidateType.equals("POINT_" + assignedTeam))
                    && !ignored.hasKey(j)
                    && !undone.hasKey(candidate["id"])) {
                return candidate["id"];
            }
        }
        return null;
    }

    private static function applyPoint(state, teamA, format) {
        if (teamA) {
            state["pointsA"] += 1;
        } else {
            state["pointsB"] += 1;
        }

        if (format["freePlay"] == true) {
            return;
        }

        var target = state["tiebreak"] == true
            ? (state["superTiebreak"] == true ? format["superTieBreakPoints"] : format["tieBreakPoints"])
            : 4;
        var pointsA = state["pointsA"];
        var pointsB = state["pointsB"];
        var margin = (pointsA - pointsB).abs();
        var won = (pointsA >= target || pointsB >= target)
            && (state["tiebreak"] == true || format["goldenPoint"] != true ? margin >= 2 : margin >= 1);
        if (won) {
            RallyMateScoreEngine.finishGame(state, pointsA > pointsB, format);
        }
    }

    private static function finishGame(state, teamA, format) {
        if (teamA) {
            state["gamesA"] += 1;
        } else {
            state["gamesB"] += 1;
        }
        state["pointsA"] = 0;
        state["pointsB"] = 0;

        if (state["tiebreak"] == true) {
            RallyMateScoreEngine.finishSet(state, teamA, format);
            return;
        }

        var gamesA = state["gamesA"];
        var gamesB = state["gamesB"];
        var gamesPerSet = format["gamesPerSet"];
        if ((gamesA >= gamesPerSet || gamesB >= gamesPerSet) && (gamesA - gamesB).abs() >= 2) {
            RallyMateScoreEngine.finishSet(state, gamesA > gamesB, format);
        } else if (format["tieBreakAtGamesAll"] == true && gamesA == gamesPerSet && gamesB == gamesPerSet) {
            state["tiebreak"] = true;
        }
    }

    private static function finishSet(state, teamA, format) {
        if (teamA) {
            state["setsA"] += 1;
        } else {
            state["setsB"] += 1;
        }
        state["gamesA"] = 0;
        state["gamesB"] = 0;
        state["pointsA"] = 0;
        state["pointsB"] = 0;
        state["tiebreak"] = false;
        state["superTiebreak"] = false;
        if (state["setsA"] >= format["setsToWin"] || state["setsB"] >= format["setsToWin"]) {
            state["complete"] = true;
        } else if (format["superTieBreakDecider"] == true
                && state["setsA"] == format["setsToWin"] - 1
                && state["setsB"] == format["setsToWin"] - 1) {
            state["tiebreak"] = true;
            state["superTiebreak"] = true;
        }
    }

    private static function formatState(state, format) {
        if (format["freePlay"] == true) {
            // Free play conta i punti grezzi e non ha game/set: le etichette
            // tennis li mapperebbero su 0/15/30/40 bloccandosi a "40" dal
            // quarto punto in poi, e a fine sessione il conteggio sparirebbe
            // dietro "0 - 0" (set). rally_core espone freePlayA/freePlayB come
            // label, quindi qui il conteggio resta grezzo anche a match chiuso.
            state["display"] = state["pointsA"].toString() + " - " + state["pointsB"].toString();
        } else if (state["complete"] == true) {
            state["display"] = state["setsA"].toString() + " - " + state["setsB"].toString();
        } else if (state["tiebreak"] == true) {
            state["display"] = state["pointsA"].toString() + " - " + state["pointsB"].toString();
        } else {
            state["display"] = RallyMateScoreEngine.tennisPoint(state["pointsA"], state["pointsB"])
                + " - " + RallyMateScoreEngine.tennisPoint(state["pointsB"], state["pointsA"]);
        }
        state["setsDisplay"] = "SET " + state["setsA"].toString() + "-" + state["setsB"].toString()
            + "  GAME " + state["gamesA"].toString() + "-" + state["gamesB"].toString();
        state["situation"] = RallyMateScoreEngine.pointSituation(state, format);
    }

    private static function pointSituation(state, format) {
        if (state["complete"] == true || state["tiebreak"] == true || format["freePlay"] == true) {
            return "";
        }
        var pointsA = state["pointsA"];
        var pointsB = state["pointsB"];
        if (pointsA < 3 || pointsB < 3) {
            return "";
        }
        if (pointsA == pointsB) {
            return format["goldenPoint"] == true
                ? "40 PARI - PUNTO DECISIVO"
                : "40 PARI - VANTAGGI";
        }
        if (pointsA == pointsB + 1) {
            return "VANTAGGIO TEAM A";
        }
        if (pointsB == pointsA + 1) {
            return "VANTAGGIO TEAM B";
        }
        return "";
    }

    private static function tennisPoint(own, other) {
        if (own >= 3 && other >= 3) {
            if (own == other) {
                return "40";
            }
            if (own == other + 1) {
                return "AD";
            }
            if (other == own + 1) {
                return "40";
            }
        }
        var labels = ["0", "15", "30", "40"];
        var index = own > 3 ? 3 : own;
        return labels[index];
    }
}

class RallyMateScoreModel {
    private var _events = [];
    private var _pendingIds = [];
    private var _matchId = null;
    private var _deviceId = null;
    private var _sequence = 0;
    private var _storageBlocked = false;
    private var _format;
    private var _assignedTeam = null;

    public function initialize() {
    }

    public function restore() {
        var stored = Storage.getValue(RM_STATE_KEY);
        if (stored != null && (stored instanceof Dictionary) && stored["version"] == 1) {
            _events = stored["events"] == null ? [] : stored["events"];
            _pendingIds = stored["pendingIds"] == null ? [] : stored["pendingIds"];
            _matchId = stored["matchId"];
            _deviceId = stored["deviceId"];
            _sequence = stored["sequence"] == null ? 0 : stored["sequence"];
            _format = RallyMateScoreEngine.normalizedFormat(stored["format"]);
            _assignedTeam = stored["assignedTeam"];
        }
        if (_format == null) {
            _format = RallyMateScoreEngine.defaultFormat();
        }
        Math.srand(Time.now().value() + System.getTimer() + (_sequence * 7919));
        if (_deviceId == null) {
            _deviceId = "garmin-" + Time.now().value().toString() + "-" + System.getTimer().toString();
        }
        if (_matchId == null) {
            _matchId = nextMatchId();
        }
        // Do not create a synthetic match just by opening the app. A local
        // match starts atomically on the first point, while a phone-provided
        // match can replace this empty state without producing ghost history.
        persist();
    }

    public function persist() {
        return saveState(_events, _pendingIds, _sequence, _matchId, _format, _assignedTeam);
    }

    public function startMatch(matchId, format, assignedTeam) {
        return startMatchWithJournal(matchId, format, assignedTeam, null);
    }

    // Starts a phone-provided match, optionally importing its full journal so
    // a paused match resumes mid-score. Imported events were already committed
    // on the phone, so they never enter _pendingIds.
    public function startMatchWithJournal(matchId, format, assignedTeam, journal) {
        if (matchId == null || matchId.toString().length() < 8) {
            return false;
        }
        var imported = sanitizeJournal(journal);
        if (imported == null) {
            return false;
        }
        // Never discard an unacknowledged match, including a completed one.
        // The phone must commit and ACK every pending event before a new match
        // may replace the active journal.
        if (_pendingIds.size() > 0) {
            return false;
        }
        // Also block overwrite of an in-progress match even if already ACKed.
        if (hasStarted()
                && score()["complete"] != true
                && _matchId != null
                && !_matchId.equals(matchId.toString())) {
            return false;
        }
        var previousEvents = _events;
        var previousPending = _pendingIds;
        var previousMatch = _matchId;
        var previousSequence = _sequence;
        var previousFormat = _format;
        var previousAssignedTeam = _assignedTeam;
        _events = [];
        _pendingIds = [];
        _matchId = matchId.toString();
        _sequence = 0;
        _format = RallyMateScoreEngine.normalizedFormat(format);
        _assignedTeam = assignedTeam instanceof String
                && (assignedTeam.equals("TEAM_A") || assignedTeam.equals("TEAM_B"))
            ? assignedTeam
            : null;
        var applied;
        if (imported.size() > 0) {
            _events = imported;
            _sequence = maxSequenceOf(imported);
            applied = persist();
        } else {
            applied = appendLifecycle("MATCH_STARTED");
        }
        if (!applied) {
            _events = previousEvents;
            _pendingIds = previousPending;
            _matchId = previousMatch;
            _sequence = previousSequence;
            _format = previousFormat;
            _assignedTeam = previousAssignedTeam;
            return false;
        }
        return true;
    }

    // Returns a validated copy of the phone journal, [] when absent, or null
    // when the journal is malformed or too large to import safely.
    private function sanitizeJournal(journal) {
        if (journal == null || !(journal instanceof Array)) {
            return [];
        }
        if (journal.size() > RM_MAX_EVENTS - 10) {
            return null;
        }
        var imported = [];
        for (var i = 0; i < journal.size(); i += 1) {
            var entry = journal[i];
            if (!(entry instanceof Dictionary)) {
                return null;
            }
            var id = entry["id"];
            if (!(id instanceof String) || id.length() < 8) {
                return null;
            }
            var type = entry["type"];
            if (!(type instanceof String) || !isImportableType(type)) {
                return null;
            }
            var sourceMethod = entry["sourceMethod"] instanceof String
                ? entry["sourceMethod"]
                : "TAP";
            var target = entry["target"] instanceof String ? entry["target"] : null;
            var sequence = entry["sequence"] instanceof Number ? entry["sequence"] : i + 1;
            // Phone epoch-ms timestamps overflow 32-bit Number and arrive as Long.
            var timestampMs = entry["timestampMs"];
            if (!(timestampMs instanceof Number) && !(timestampMs instanceof Long)) {
                timestampMs = Time.now().value() * 1000;
            }
            var event = {
                "id" => id,
                "type" => type,
                "sourceMethod" => sourceMethod,
                "target" => target,
                "sequence" => sequence,
                "timestampMs" => timestampMs
            };
            if (entry["teamId"] instanceof String) {
                event["teamId"] = entry["teamId"];
            }
            imported.add(event);
        }
        return imported;
    }

    private function isImportableType(type) {
        return type.equals("MATCH_STARTED")
            || type.equals("POINT_TEAM_A")
            || type.equals("POINT_TEAM_B")
            || type.equals("UNDO")
            || type.equals("MATCH_PAUSED")
            || type.equals("MATCH_RESUMED")
            || type.equals("MATCH_COMPLETED");
    }

    private function maxSequenceOf(events) {
        var maximum = events.size();
        for (var i = 0; i < events.size(); i += 1) {
            var sequence = events[i]["sequence"];
            if (sequence instanceof Number && sequence > maximum) {
                maximum = sequence;
            }
        }
        return maximum;
    }

    public function appendPoint(type, sourceMethod) {
        if (type == null
                || (!type.equals("POINT_TEAM_A") && !type.equals("POINT_TEAM_B"))
                || isStorageBlocked()) {
            return false;
        }
        if (_assignedTeam != null && !type.equals("POINT_" + _assignedTeam)) {
            return false;
        }
        var currentScore = score();
        if (currentScore["paused"] == true
                || currentScore["complete"] == true
                || _events.size() >= RM_MAX_EVENTS - 3) {
            _storageBlocked = _events.size() >= RM_MAX_EVENTS - 3;
            return false;
        }

        var candidateEvents = copyArray(_events);
        var candidatePending = copyArray(_pendingIds);
        var candidateSequence = _sequence;
        if (candidateEvents.size() == 0) {
            candidateSequence += 1;
            var started = makeEvent("MATCH_STARTED", "AUTO", null, candidateSequence);
            candidateEvents.add(started);
            candidatePending.add(started["id"]);
        }
        candidateSequence += 1;
        var event = makeEvent(type, sourceMethod, null, candidateSequence);
        candidateEvents.add(event);
        candidatePending.add(event["id"]);

        if (RallyMateScoreEngine.replay(candidateEvents, _format)["complete"] == true) {
            candidateSequence += 1;
            var completed = makeEvent("MATCH_COMPLETED", "AUTO", null, candidateSequence);
            candidateEvents.add(completed);
            candidatePending.add(completed["id"]);
        }
        return commit(candidateEvents, candidatePending, candidateSequence);
    }

    public function appendUndo(sourceMethod) {
        if (score()["paused"] == true) {
            return false;
        }
        var target = lastUndoableEventId();
        if (target == null || _events.size() >= RM_MAX_EVENTS) {
            return false;
        }
        var teamId = null;
        for (var j = _events.size() - 1; j >= 0; j -= 1) {
            if (_events[j]["id"].equals(target)) {
                var targetType = _events[j]["type"];
                if (targetType != null && targetType.equals("POINT_TEAM_A")) {
                    teamId = "TEAM_A";
                } else if (targetType != null && targetType.equals("POINT_TEAM_B")) {
                    teamId = "TEAM_B";
                }
                break;
            }
        }
        var candidateEvents = copyArray(_events);
        var candidatePending = copyArray(_pendingIds);
        var candidateSequence = _sequence + 1;
        var event = makeEvent("UNDO", sourceMethod, target, candidateSequence);
        if (teamId != null) {
            event["teamId"] = teamId;
        }
        candidateEvents.add(event);
        candidatePending.add(event["id"]);
        return commit(candidateEvents, candidatePending, candidateSequence);
    }

    public function appendLifecycle(type) {
        return appendLifecycleWithSource(type, "AUTO");
    }

    public function pauseMatch() {
        var current = score();
        if (current["complete"] == true || current["paused"] == true || !hasStarted()) {
            return false;
        }
        return appendLifecycleWithSource("MATCH_PAUSED", "TAP");
    }

    public function resumeMatch() {
        var current = score();
        if (current["complete"] == true || current["paused"] != true) {
            return false;
        }
        return appendLifecycleWithSource("MATCH_RESUMED", "TAP");
    }

    public function finishMatch() {
        var current = score();
        if (current["complete"] == true || !hasStarted()) {
            return false;
        }
        return appendLifecycleWithSource("MATCH_COMPLETED", "MANUAL_EDIT");
    }

    public function startLocalMatch(formatId) {
        var format = formatId == null || formatId.equals("LAST")
            ? _format
            : RallyMateScoreEngine.preset(formatId);
        return startMatch(nextMatchId(), format, null);
    }

    public function hasStarted() {
        return _events.size() > 0 && score()["started"] == true;
    }

    private function appendLifecycleWithSource(type, sourceMethod) {
        var candidateEvents = copyArray(_events);
        var candidatePending = copyArray(_pendingIds);
        var candidateSequence = _sequence + 1;
        var event = makeEvent(type, sourceMethod, null, candidateSequence);
        candidateEvents.add(event);
        candidatePending.add(event["id"]);
        return commit(candidateEvents, candidatePending, candidateSequence);
    }

    public function acknowledge(eventIds) {
        var acknowledged = {};
        for (var i = 0; i < eventIds.size(); i += 1) {
            acknowledged[eventIds[i]] = true;
        }
        var remaining = [];
        for (var j = 0; j < _pendingIds.size(); j += 1) {
            if (acknowledged[_pendingIds[j]] != true) {
                remaining.add(_pendingIds[j]);
            }
        }
        if (saveState(_events, remaining, _sequence, _matchId, _format, _assignedTeam)) {
            _pendingIds = remaining;
            _storageBlocked = false;
            return true;
        }
        return false;
    }

    public function pendingEvents() {
        var pending = {};
        for (var i = 0; i < _pendingIds.size(); i += 1) {
            pending[_pendingIds[i]] = true;
        }
        var result = [];
        for (var j = 0; j < _events.size() && result.size() < RM_MAX_BATCH; j += 1) {
            if (pending[_events[j]["id"]] == true) {
                result.add(_events[j]);
            }
        }
        return result;
    }

    public function score() {
        return RallyMateScoreEngine.replay(_events, _format);
    }

    public function pendingCount() {
        return _pendingIds.size();
    }

    public function isStorageBlocked() {
        return _storageBlocked;
    }

    public function matchId() {
        return _matchId;
    }

    public function deviceId() {
        return _deviceId;
    }

    public function format() {
        return _format;
    }

    public function assignedTeam() {
        return _assignedTeam;
    }

    public function canUndo() {
        return lastUndoableEventId() != null;
    }

    private function commit(events, pendingIds, sequence) {
        if (!saveState(events, pendingIds, sequence, _matchId, _format, _assignedTeam)) {
            _storageBlocked = true;
            return false;
        }
        _events = events;
        _pendingIds = pendingIds;
        _sequence = sequence;
        _storageBlocked = false;
        return true;
    }

    private function saveState(events, pendingIds, sequence, matchId, format, assignedTeam) {
        try {
            Storage.setValue(RM_STATE_KEY, {
                "version" => 1,
                "deviceId" => _deviceId,
                "matchId" => matchId,
                "sequence" => sequence,
                "format" => format,
                "assignedTeam" => assignedTeam,
                "events" => events,
                "pendingIds" => pendingIds
            });
            return true;
        } catch (error) {
            System.println("RallyMate persistence failed: " + error.toString());
            return false;
        }
    }

    private function makeEvent(type, sourceMethod, target, sequence) {
        return {
            "id" => nextEventId(sequence),
            "type" => type,
            "sourceMethod" => sourceMethod,
            "target" => target,
            "sequence" => sequence,
            "timestampMs" => Time.now().value() * 1000
        };
    }

    private function lastUndoableEventId() {
        return RallyMateScoreEngine.lastUndoableEventIdIn(_events, _assignedTeam);
    }

    private function nextEventId(sequence) {
        var variants = "89ab";
        var variantIndex = Math.rand() % 4;
        return randomHex(8) + "-" + randomHex(4) + "-4" + randomHex(3) + "-"
            + variants.substring(variantIndex, variantIndex + 1) + randomHex(3) + "-"
            + randomHex(12);
    }

    private function randomHex(length) {
        var alphabet = "0123456789abcdef";
        var value = "";
        for (var i = 0; i < length; i += 1) {
            var index = Math.rand() % 16;
            value += alphabet.substring(index, index + 1);
        }
        return value;
    }

    private function nextMatchId() {
        return "match-" + Time.now().value().toString() + "-" + System.getTimer().toString()
            + "-" + (_sequence + 1).toString();
    }

    private function copyArray(input) {
        var output = [];
        for (var i = 0; i < input.size(); i += 1) {
            output.add(input[i]);
        }
        return output;
    }
}
