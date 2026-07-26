import Toybox.Application.Storage;
import Toybox.Lang;

const RM_RESUMABLE_KEY = "rallymate_resumable_v1";
const RM_LIFECYCLE_KEYS = "rallymate_lifecycle_keys_v1";
const RM_LIFECYCLE_KEYS_LIMIT = 32;

// Lifecycle status shared with the phone, mirroring MatchStatus in rally_core.
const RM_STATUS_CREATED = "CREATED";
const RM_STATUS_IN_PROGRESS = "IN_PROGRESS";
const RM_STATUS_PAUSED = "PAUSED";
const RM_STATUS_COMPLETED = "COMPLETED";
const RM_STATUS_ABANDONED = "ABANDONED";

// Deterministic merge of the resumable-match snapshot, identical to the
// watchOS and Wear OS rules:
//   * a terminal status always wins over a resumable one;
//   * otherwise the higher stateVersion wins;
//   * equal versions keep the most recently updated entry.
// stateVersion is the journal length, so every device derives the same number
// from the same events without comparing clocks.
class RallyMateResumablePolicy {
    public static function isTerminal(status) {
        return status != null
            && (status.equals(RM_STATUS_COMPLETED) || status.equals(RM_STATUS_ABANDONED));
    }

    public static function isResumable(status) {
        return status != null
            && (status.equals(RM_STATUS_IN_PROGRESS)
                || status.equals(RM_STATUS_PAUSED)
                || status.equals(RM_STATUS_CREATED));
    }

    public static function normalizeStatus(status) {
        if (status == null) {
            return RM_STATUS_IN_PROGRESS;
        }
        if (status.equals(RM_STATUS_CREATED)
                || status.equals(RM_STATUS_IN_PROGRESS)
                || status.equals(RM_STATUS_PAUSED)
                || status.equals(RM_STATUS_COMPLETED)
                || status.equals(RM_STATUS_ABANDONED)) {
            return status;
        }
        return RM_STATUS_IN_PROGRESS;
    }

    public static function statusForAction(action) {
        if (action == null) {
            return RM_STATUS_IN_PROGRESS;
        }
        if (action.equals("PAUSED")) {
            return RM_STATUS_PAUSED;
        }
        if (action.equals("COMPLETED")) {
            return RM_STATUS_COMPLETED;
        }
        if (action.equals("ABANDONED")) {
            return RM_STATUS_ABANDONED;
        }
        return RM_STATUS_IN_PROGRESS;
    }

    private static function intOf(value) {
        return value instanceof Number ? value : 0;
    }

    public static function winner(existing, incoming) {
        if (!(existing instanceof Dictionary)) {
            return incoming;
        }
        if (!(incoming instanceof Dictionary)) {
            return existing;
        }
        var existingTerminal = isTerminal(existing["status"]);
        var incomingTerminal = isTerminal(incoming["status"]);
        if (existingTerminal && !incomingTerminal) {
            return existing;
        }
        if (incomingTerminal && !existingTerminal) {
            return incoming;
        }
        var existingVersion = intOf(existing["stateVersion"]);
        var incomingVersion = intOf(incoming["stateVersion"]);
        if (incomingVersion > existingVersion) {
            return incoming;
        }
        if (incomingVersion < existingVersion) {
            return existing;
        }
        return intOf(incoming["updatedAt"]) >= intOf(existing["updatedAt"])
            ? incoming
            : existing;
    }

    // Merges one entry into the stored list, most recent first.
    public static function merge(existingList, entry) {
        var result = [];
        var replaced = false;
        if (existingList instanceof Array) {
            for (var i = 0; i < existingList.size(); i += 1) {
                var current = existingList[i];
                if (!(current instanceof Dictionary)) {
                    continue;
                }
                if (entry instanceof Dictionary
                        && current["matchId"] != null
                        && entry["matchId"] != null
                        && current["matchId"].equals(entry["matchId"])) {
                    result.add(winner(current, entry));
                    replaced = true;
                } else {
                    result.add(current);
                }
            }
        }
        if (!replaced && entry instanceof Dictionary && entry["matchId"] != null) {
            result.add(entry);
        }
        return sortByUpdatedAt(result);
    }

    public static function sortByUpdatedAt(list) {
        // Insertion sort: the list is tiny (a handful of open matches) and
        // Monkey C has no stable comparator sort on all products.
        var sorted = [];
        for (var i = 0; i < list.size(); i += 1) {
            var entry = list[i];
            var inserted = false;
            for (var j = 0; j < sorted.size(); j += 1) {
                if (intOf(entry["updatedAt"]) > intOf(sorted[j]["updatedAt"])) {
                    sorted.add(null);
                    for (var k = sorted.size() - 1; k > j; k -= 1) {
                        sorted[k] = sorted[k - 1];
                    }
                    sorted[j] = entry;
                    inserted = true;
                    break;
                }
            }
            if (!inserted) {
                sorted.add(entry);
            }
        }
        return sorted;
    }

    public static function resumableOnly(list) {
        var result = [];
        if (!(list instanceof Array)) {
            return result;
        }
        for (var i = 0; i < list.size(); i += 1) {
            var entry = list[i];
            if (entry instanceof Dictionary && isResumable(entry["status"])) {
                result.add(entry);
            }
        }
        return result;
    }
}

// Maps a phone rejection reason to the string shown on the watch. Unknown
// reasons still produce a readable message instead of silence.
class RallyMateResumeRejection {
    public static function messageFor(reason) {
        if (reason != null && reason.equals("journal_unsupported")) {
            return Rez.Strings.ResumeNotOnWatch;
        }
        if (reason != null && reason.equals("not_resumable")) {
            return Rez.Strings.ResumeAlreadyClosed;
        }
        return Rez.Strings.ResumeFailed;
    }
}

// Persistent store of the matches the user may resume from this watch.
class RallyMateResumableStore {
    public function list() {
        var stored = Storage.getValue(RM_RESUMABLE_KEY);
        return stored instanceof Array ? stored : [];
    }

    public function resumable() {
        return RallyMateResumablePolicy.resumableOnly(list());
    }

    public function find(matchId) {
        var entries = list();
        for (var i = 0; i < entries.size(); i += 1) {
            var entry = entries[i];
            if (entry instanceof Dictionary
                    && entry["matchId"] != null
                    && matchId != null
                    && entry["matchId"].equals(matchId)) {
                return entry;
            }
        }
        return null;
    }

    public function apply(entry) {
        var merged = RallyMateResumablePolicy.merge(list(), entry);
        Storage.setValue(RM_RESUMABLE_KEY, merged);
        return merged;
    }

    // Idempotency guard: the phone transport may redeliver the same payload.
    // Returns true the first time a key is seen.
    public function markApplied(key) {
        if (key == null || key.equals("")) {
            return true;
        }
        var seen = Storage.getValue(RM_LIFECYCLE_KEYS);
        if (!(seen instanceof Array)) {
            seen = [];
        }
        for (var i = 0; i < seen.size(); i += 1) {
            if (seen[i] != null && seen[i].equals(key)) {
                return false;
            }
        }
        seen.add(key);
        while (seen.size() > RM_LIFECYCLE_KEYS_LIMIT) {
            seen = seen.slice(1, seen.size());
        }
        Storage.setValue(RM_LIFECYCLE_KEYS, seen);
        return true;
    }

    // Applies a lifecycle payload sent by the phone. Returns true when the
    // stored list changed.
    public function applyLifecycle(data) {
        if (!(data instanceof Dictionary)) {
            return false;
        }
        var matchId = data["matchId"];
        if (matchId == null) {
            return false;
        }
        var action = data["action"];
        var stateVersion = data["stateVersion"] instanceof Number
            ? data["stateVersion"]
            : 0;
        var key = data["idempotencyKey"];
        if (key == null) {
            key = matchId + "#" + (action == null ? "" : action) + "#" + stateVersion.toString();
        }
        if (!markApplied(key)) {
            return false;
        }
        var known = find(matchId);
        var status = RallyMateResumablePolicy.normalizeStatus(
            data["status"] != null
                ? data["status"]
                : RallyMateResumablePolicy.statusForAction(action)
        );
        if (known instanceof Dictionary
                && known["stateVersion"] instanceof Number
                && stateVersion < known["stateVersion"]
                && !RallyMateResumablePolicy.isTerminal(status)) {
            // A lower version never overwrites a newer local state.
            return false;
        }
        apply({
            "matchId" => matchId,
            "status" => status,
            "stateVersion" => stateVersion,
            "updatedAt" => data["ts"] instanceof Number ? data["ts"] : 0,
            "scoreLine" => data["scoreLine"] == null ? "" : data["scoreLine"],
            "setsLabel" => data["setsLabel"] == null ? "" : data["setsLabel"],
            "gamesLabel" => data["gamesLabel"] == null ? "" : data["gamesLabel"],
            "teamLabel" => data["teamLabel"] == null ? "" : data["teamLabel"],
            "format" => data["format"]
        });
        return true;
    }

    // Applies the snapshot of every resumable match at once.
    public function applySnapshot(data) {
        if (!(data instanceof Dictionary)) {
            return false;
        }
        var matches = data["matches"];
        if (!(matches instanceof Array)) {
            return false;
        }
        var changed = false;
        for (var i = 0; i < matches.size(); i += 1) {
            var entry = matches[i];
            if (!(entry instanceof Dictionary) || entry["matchId"] == null) {
                continue;
            }
            apply({
                "matchId" => entry["matchId"],
                "status" => RallyMateResumablePolicy.normalizeStatus(entry["status"]),
                "stateVersion" => entry["stateVersion"] instanceof Number
                    ? entry["stateVersion"]
                    : 0,
                "updatedAt" => entry["updatedAtMs"] instanceof Number
                    ? entry["updatedAtMs"]
                    : (entry["updatedAt"] instanceof Number ? entry["updatedAt"] : 0),
                "scoreLine" => entry["scoreLine"] == null ? "" : entry["scoreLine"],
                "setsLabel" => entry["setsLabel"] == null ? "" : entry["setsLabel"],
                "gamesLabel" => entry["gamesLabel"] == null ? "" : entry["gamesLabel"],
                "teamLabel" => entry["teamLabel"] == null ? "" : entry["teamLabel"],
                "format" => entry["format"]
            });
            changed = true;
        }
        return changed;
    }
}
