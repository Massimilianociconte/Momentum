import Toybox.Communications;
import Toybox.Attention;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

class RallyMateEnergyPolicy {
    public static function retryDelay(attempt) {
        if (attempt <= 0) { return 5000; }
        if (attempt == 1) { return 15000; }
        if (attempt == 2) { return 30000; }
        if (attempt == 3) { return 60000; }
        return 120000;
    }
}

class RallyMateConnectionListener extends Communications.ConnectionListener {
    private var _sync;

    public function initialize(sync) {
        Communications.ConnectionListener.initialize();
        _sync = sync;
    }

    public function onComplete() {
        _sync.transportComplete();
    }

    public function onError() {
        _sync.transportFailed();
    }
}

class RallyMateSync {
    private var _model;
    private var _activity;
    private var _resumable;
    private var _sending = false;
    private var _retryTimer;
    private var _retryScheduled = false;
    private var _retryAttempt = 0;

    public function initialize(model, activity) {
        _model = model;
        _activity = activity;
        _resumable = new RallyMateResumableStore();
        _retryTimer = new Timer.Timer();
    }

    // Matches the user may resume from this watch, most recent first.
    public function resumableMatches() {
        return _resumable.resumable();
    }

    public function resumableStore() {
        return _resumable;
    }

    public function isSending() {
        return _sending;
    }

    public function flush() {
        if (_sending || !(Communications has :transmit)) {
            return;
        }
        var pending = _model.pendingEvents();
        if (pending.size() == 0) {
            return;
        }
        cancelRetry();

        var envelopes = [];
        for (var i = 0; i < pending.size(); i += 1) {
            var event = pending[i];
            envelopes.add({
                "protocolVersion" => 1,
                "deviceFamily" => "garmin_connect_iq",
                "deviceId" => _model.deviceId(),
                "matchId" => _model.matchId(),
                "eventId" => event["id"],
                "eventType" => event["type"],
                "timestampMs" => event["timestampMs"],
                "payload" => {
                    "type" => event["type"],
                    "sourceMethod" => event["sourceMethod"],
                    "targetEventId" => event["target"],
                    "teamId" => teamIdForEvent(event),
                    "sequence" => event["sequence"],
                    "format" => _model.format()
                }
            });
        }

        _sending = true;
        try {
            Communications.transmit({
                "type" => "EVENT_BATCH",
                "protocolVersion" => 1,
                "events" => envelopes
            }, null, new RallyMateConnectionListener(self));
        } catch (error) {
            System.println("RallyMate transmit failed: " + error.toString());
            _sending = false;
            scheduleRetry();
        }
    }

    public function handlePhoneMessage(rawData) {
        var data = rawData;
        if (data instanceof Array && data.size() > 0) {
            data = data[0];
        }
        if (!(data instanceof Dictionary)) {
            return;
        }

        var type = data["type"];
        if (type != null && type.equals("ACK") && data["eventIds"] instanceof Array) {
            _model.acknowledge(data["eventIds"]);
            _sending = false;
            cancelRetry();
            _retryAttempt = 0;
            flush();
        } else if (type != null && type.equals("REQUEST_SYNC")) {
            _sending = false;
            userActivity();
            flush();
        } else if (type != null && type.equals("START_MATCH")) {
            userActivity();
            var accepted = _model.startMatchWithJournal(
                data["matchId"], data["format"], data["assignedTeam"], data["events"]);
            var rejectReason = null;
            if (!accepted) {
                if (_model.pendingCount() > 0) {
                    rejectReason = "pending_match_not_synchronized";
                } else if (_model.hasStarted() && _model.score()["complete"] != true) {
                    rejectReason = "active_match_in_progress";
                } else {
                    rejectReason = "invalid_payload";
                }
            }
            sendImmediate({
                "type" => accepted ? "START_MATCH_ACK" : "START_MATCH_REJECTED",
                "matchId" => data["matchId"],
                "reason" => rejectReason
            });
            flush();
        } else if (type != null && type.equals("MATCH_LIFECYCLE")) {
            // Durable pause/resume/complete from the phone. Idempotent and
            // version-guarded inside the store.
            userActivity();
            if (_resumable.applyLifecycle(data)) {
                WatchUi.requestUpdate();
            }
        } else if (type != null && type.equals("RESUME_REJECTED")) {
            // The phone cannot hand this match over. Say so: the user tapped
            // Resume and would otherwise wait forever.
            userActivity();
            if (WatchUi has :showToast) {
                WatchUi.showToast(
                    RallyMateResumeRejection.messageFor(data["reason"]),
                    null
                );
            }
        } else if (type != null && type.equals("RESUMABLE_SNAPSHOT")) {
            // Latest snapshot of the matches the user may resume.
            userActivity();
            if (_resumable.applySnapshot(data)) {
                WatchUi.requestUpdate();
            }
        } else if (type != null && type.equals("PING")) {
            sendStatus("PONG");
        } else if (type != null && type.equals("TEST_POINT")) {
            if (Attention has :vibrate) {
                Attention.vibrate([new Attention.VibeProfile(55, 70)]);
            }
            sendStatus("TEST_POINT_ACK");
        } else if (type != null
                && (type.equals("CONFIGURE") || type.equals("REQUEST_STATE"))) {
            sendStatus("READY");
            flush();
        }
    }

    public function transportComplete() {
        _sending = false;
        // Transport completion means the phone received the parcel, not that
        // the backend committed it. Events remain pending until an explicit ACK.
        if (_model.pendingCount() > 0) {
            scheduleRetry();
        }
    }

    public function transportFailed() {
        _sending = false;
        scheduleRetry();
    }

    public function shutdown() {
        cancelRetry();
        _sending = false;
    }

    public function userActivity() {
        cancelRetry();
        _retryAttempt = 0;
    }

    // Asks the phone to reply with a full START_MATCH carrying the journal of
    // the given resumable match.
    public function requestResume(matchId) {
        if (matchId == null) {
            return false;
        }
        userActivity();
        sendImmediate({
            "type" => "REQUEST_RESUME",
            "protocolVersion" => 1,
            "deviceFamily" => "garmin_connect_iq",
            "deviceId" => _model.deviceId(),
            "matchId" => matchId
        });
        return true;
    }

    private function sendStatus(type) {
        sendImmediate({
            "type" => type,
            "protocolVersion" => 1,
            "deviceFamily" => "garmin_connect_iq",
            "deviceId" => _model.deviceId(),
            "matchId" => _model.matchId(),
            "pendingEvents" => _model.pendingCount(),
            "score" => _model.score(),
            "activityStatus" => _activity.status(),
            "capabilities" => [
                "offline_scoring",
                "deuce",
                "undo",
                "pause_resume",
                "manual_finish",
                "watch_quick_start",
                "owned_fit_activity",
                "padel_subsport_when_supported",
                "touch",
                "buttons"
            ]
        });
    }

    private function sendImmediate(payload) {
        if (_sending || !(Communications has :transmit)) {
            return;
        }
        _sending = true;
        try {
            Communications.transmit(payload, null, new RallyMateConnectionListener(self));
        } catch (error) {
            System.println("RallyMate immediate transmit failed: " + error.toString());
            _sending = false;
        }
    }

    /// Derives TEAM_A / TEAM_B for POINT_* and UNDO (via target point type).
    private function teamIdForEvent(event) {
        var type = event["type"];
        if (type != null && type.equals("POINT_TEAM_A")) {
            return "TEAM_A";
        }
        if (type != null && type.equals("POINT_TEAM_B")) {
            return "TEAM_B";
        }
        if (event["teamId"] instanceof String) {
            return event["teamId"];
        }
        return null;
    }

    private function scheduleRetry() {
        if (_retryScheduled || _model.pendingCount() == 0) {
            return;
        }
        _retryScheduled = true;
        var delay = RallyMateEnergyPolicy.retryDelay(_retryAttempt);
        _retryAttempt += 1;
        _retryTimer.start(method(:retryPending), delay, false);
    }

    public function retryPending() {
        _retryScheduled = false;
        flush();
    }

    private function cancelRetry() {
        if (!_retryScheduled) {
            return;
        }
        _retryTimer.stop();
        _retryScheduled = false;
    }
}
