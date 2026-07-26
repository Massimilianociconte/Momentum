import Toybox.Attention;
import Toybox.System;
import Toybox.WatchUi;

class RallyMateDelegate extends WatchUi.BehaviorDelegate {
    private var _model;
    private var _activity;
    private var _sync;
    private var _view;
    private var _lastPointAt = -1000;

    public function initialize(model, activity, sync, view) {
        BehaviorDelegate.initialize();
        _model = model;
        _activity = activity;
        _sync = sync;
        _view = view;
    }

    public function onKey(event) {
        var key = event.getKey();
        if (key == WatchUi.KEY_UP || key == WatchUi.KEY_ENTER) {
            return scorePoint("POINT_TEAM_A", "TAP");
        }
        if (key == WatchUi.KEY_DOWN) {
            return scorePoint("POINT_TEAM_B", "TAP");
        }
        // Preserve Garmin's native Back behavior. Undo lives on the standard
        // Menu action (long-press Menu/Up depending on the device family).
        if (key == WatchUi.KEY_ESC) {
            return false;
        }
        return false;
    }

    public function onMenu() {
        openActions();
        return true;
    }

    public function onTap(event) {
        var coordinates = event.getCoordinates();
        var action = _view.tapAction(coordinates[0], coordinates[1]);
        if (action == null) {
            return false;
        }
        if (action.equals("UNDO")) {
            return undo("TAP");
        }
        if (action.equals("MENU")) {
            openActions();
            return true;
        }
        return scorePoint(action, "TAP");
    }

    public function onSwipe(event) {
        // Do not steal system back/navigation swipes on touch devices.
        return false;
    }

    private function scorePoint(type, sourceMethod) {
        var now = System.getTimer();
        if (now - _lastPointAt < 350) {
            haptic(true);
            return true;
        }
        var assigned = _model.assignedTeam();
        if (assigned != null) {
            type = "POINT_" + assigned;
        }
        var wasStarted = _model.hasStarted();
        if (_model.appendPoint(type, sourceMethod)) {
            if (!wasStarted) {
                _activity.startForMatch(_model.matchId());
            }
            if (_model.score()["complete"] == true) {
                _activity.completeForMatch(_model.matchId());
            }
            _lastPointAt = now;
            haptic(false);
            _sync.userActivity();
            _sync.flush();
            WatchUi.requestUpdate();
            return true;
        }
        haptic(true);
        WatchUi.requestUpdate();
        return false;
    }

    private function undo(sourceMethod) {
        if (_model.appendUndo(sourceMethod)) {
            haptic(true);
            _sync.userActivity();
            _sync.flush();
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    private function openActions() {
        var menu = new WatchUi.Menu();
        menu.setTitle(Rez.Strings.Actions);
        var score = _model.score();

        if (score["complete"] != true && _model.canUndo()) {
            menu.addItem(Rez.Strings.Undo, :action_undo);
        }
        if (_model.hasStarted() && score["complete"] != true) {
            menu.addItem(
                score["paused"] == true ? Rez.Strings.Resume : Rez.Strings.Pause,
                score["paused"] == true ? :resume : :pause
            );
            menu.addItem(Rez.Strings.FinishMatch, :finish);
        }
        if ((!_model.hasStarted() || score["complete"] == true) && _model.pendingCount() == 0) {
            // Recording owner is chosen before the match, like on the other
            // platforms: two activities can never run at the same time.
            menu.addItem(Rez.Strings.RecordingChoice, :recording);
            // Paused/in-progress matches on the phone: ask for a full handoff
            // (START_MATCH with journal) before offering fresh formats.
            var resumables = _sync.resumableMatches();
            var resumeSymbols = [:resume_remote_0, :resume_remote_1, :resume_remote_2];
            for (var i = 0; i < resumables.size() && i < resumeSymbols.size(); i += 1) {
                menu.addItem(resumeLabel(resumables[i]), resumeSymbols[i]);
            }
            menu.addItem(Rez.Strings.QuickStart, :new_last);
            menu.addItem(Rez.Strings.Advantages, :new_advantage);
            menu.addItem(Rez.Strings.GoldenPoint, :new_golden);
            menu.addItem(Rez.Strings.SingleSet, :new_single);
            menu.addItem(Rez.Strings.FreeTraining, :new_training);
        }
        menu.addItem(Rez.Strings.SyncNow, :sync);
        WatchUi.pushView(
            menu,
            new RallyMateActionMenuDelegate(_model, _activity, _sync, _sync.resumableMatches()),
            WatchUi.SLIDE_UP
        );
    }

    private function resumeLabel(entry) {
        var label = WatchUi.loadResource(Rez.Strings.ResumeFromPhone);
        if (entry["setsLabel"] != null && !entry["setsLabel"].equals("")) {
            label += " " + entry["setsLabel"];
        }
        if (entry["gamesLabel"] != null && !entry["gamesLabel"].equals("")) {
            label += " " + entry["gamesLabel"];
        }
        return label;
    }

    private function haptic(isWarning) {
        if (!(Attention has :vibrate)) {
            return;
        }
        var duration = isWarning ? 140 : 55;
        var strength = isWarning ? 85 : 45;
        Attention.vibrate([new Attention.VibeProfile(strength, duration)]);
    }
}

class RallyMateActionMenuDelegate extends WatchUi.MenuInputDelegate {
    private var _model;
    private var _activity;
    private var _sync;
    private var _resumables;

    public function initialize(model, activity, sync, resumables) {
        MenuInputDelegate.initialize();
        _model = model;
        _activity = activity;
        _sync = sync;
        _resumables = resumables;
    }

    public function onMenuItem(item) {
        if (item == :resume_remote_0 || item == :resume_remote_1 || item == :resume_remote_2) {
            var index = item == :resume_remote_0 ? 0 : (item == :resume_remote_1 ? 1 : 2);
            if (_resumables != null && index < _resumables.size()) {
                _sync.requestResume(_resumables[index]["matchId"]);
                if (WatchUi has :showToast) {
                    WatchUi.showToast(Rez.Strings.ResumeRequested, null);
                }
                menuHaptic(false);
            }
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.requestUpdate();
            return;
        }
        if (item == :recording) {
            var recording = new WatchUi.Menu();
            recording.setTitle(Rez.Strings.RecordingChoice);
            recording.addItem(Rez.Strings.RecordingRallyMate, :recording_rallymate);
            recording.addItem(Rez.Strings.RecordingExternal, :recording_external);
            recording.addItem(Rez.Strings.RecordingDisabled, :recording_disabled);
            WatchUi.pushView(
                recording,
                new RallyMateRecordingMenuDelegate(_activity),
                WatchUi.SLIDE_UP
            );
            return;
        }
        if (item == :finish) {
            var confirm = new WatchUi.Menu();
            confirm.setTitle(Rez.Strings.FinishConfirmTitle);
            confirm.addItem(Rez.Strings.ConfirmFinish, :confirm_finish);
            confirm.addItem(Rez.Strings.Cancel, :cancel);
            WatchUi.pushView(
                confirm,
                new RallyMateFinishMenuDelegate(_model, _activity, _sync),
                WatchUi.SLIDE_UP
            );
            return;
        }

        var changed = false;
        if (item == :action_undo) {
            changed = _model.appendUndo("TAP");
        } else if (item == :pause) {
            changed = _model.pauseMatch();
            if (changed) {
                _activity.pauseForMatch(_model.matchId());
            }
        } else if (item == :resume) {
            changed = _model.resumeMatch();
            if (changed) {
                _activity.resumeForMatch(_model.matchId());
            }
        } else if (item == :new_last) {
            changed = _model.startLocalMatch("LAST");
        } else if (item == :new_advantage) {
            changed = _model.startLocalMatch("ADV_BO3");
        } else if (item == :new_golden) {
            changed = _model.startLocalMatch("GOLDEN_BO3");
        } else if (item == :new_single) {
            changed = _model.startLocalMatch("SINGLE_SET");
        } else if (item == :new_training) {
            changed = _model.startLocalMatch("TRAINING");
        }

        if (changed && (item == :new_last
                || item == :new_advantage
                || item == :new_golden
                || item == :new_single
                || item == :new_training)) {
            _activity.startForMatch(_model.matchId());
        }

        if (changed || item == :sync) {
            _sync.userActivity();
            _sync.flush();
            menuHaptic(!changed && item != :sync);
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        WatchUi.requestUpdate();
    }

    private function menuHaptic(warning) {
        if (Attention has :vibrate) {
            Attention.vibrate([
                new Attention.VibeProfile(warning ? 85 : 45, warning ? 140 : 55)
            ]);
        }
    }
}

// Recording owner for the next match. Never changes a running recording.
class RallyMateRecordingMenuDelegate extends WatchUi.MenuInputDelegate {
    private var _activity;

    public function initialize(activity) {
        MenuInputDelegate.initialize();
        _activity = activity;
    }

    public function onMenuItem(item) {
        if (item == :recording_rallymate) {
            _activity.setRecordingMode(RM_MODE_RALLYMATE);
        } else if (item == :recording_external) {
            _activity.setRecordingMode(RM_MODE_EXTERNAL);
        } else if (item == :recording_disabled) {
            _activity.setRecordingMode(RM_MODE_DISABLED);
        }
        if (WatchUi has :showToast) {
            WatchUi.showToast(Rez.Strings.RecordingNote, null);
        }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        WatchUi.requestUpdate();
    }
}

class RallyMateFinishMenuDelegate extends WatchUi.MenuInputDelegate {
    private var _model;
    private var _activity;
    private var _sync;

    public function initialize(model, activity, sync) {
        MenuInputDelegate.initialize();
        _model = model;
        _activity = activity;
        _sync = sync;
    }

    public function onMenuItem(item) {
        if (item == :cancel) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return;
        }
        if (item != :confirm_finish) {
            return;
        }

        var completed = _model.finishMatch();
        if (completed) {
            _activity.completeForMatch(_model.matchId());
            _sync.userActivity();
            _sync.flush();
            if (Attention has :vibrate) {
                Attention.vibrate([new Attention.VibeProfile(60, 120)]);
            }
        }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        WatchUi.requestUpdate();
    }
}
