import Toybox.Activity;
import Toybox.Application.Storage;
import Toybox.Test;

function rmTestPoint(events, type, id) {
    events.add({
        "id" => id,
        "type" => type,
        "target" => null
    });
}

function rmAdvantageFormat() {
    return RallyMateScoreEngine.defaultFormat();
}

function rmIsUuidV4(value) {
    if (value == null || value.length() != 36) {
        return false;
    }
    var variant = value.substring(19, 20);
    return value.substring(8, 9).equals("-")
        && value.substring(13, 14).equals("-")
        && value.substring(18, 19).equals("-")
        && value.substring(23, 24).equals("-")
        && value.substring(14, 15).equals("4")
        && (variant.equals("8") || variant.equals("9")
            || variant.equals("a") || variant.equals("b"));
}

(:test)
function testDeuceAdvantageReturnsToDeuce(logger) {
    var events = [];
    for (var i = 0; i < 3; i += 1) {
        rmTestPoint(events, "POINT_TEAM_A", "a" + i.toString());
        rmTestPoint(events, "POINT_TEAM_B", "b" + i.toString());
    }
    var deuce = RallyMateScoreEngine.replay(events, rmAdvantageFormat());
    Test.assertEqualMessage("40 - 40", deuce["display"], "40 pari non riconosciuto");
    Test.assertEqualMessage("40 PARI - VANTAGGI", deuce["situation"], "stato 40 pari non esposto");
    rmTestPoint(events, "POINT_TEAM_A", "adv-a");
    var advantage = RallyMateScoreEngine.replay(events, rmAdvantageFormat());
    Test.assertEqualMessage("AD - 40", advantage["display"], "vantaggio A errato");
    Test.assertEqualMessage("VANTAGGIO TEAM A", advantage["situation"], "stato vantaggio A non esposto");
    rmTestPoint(events, "POINT_TEAM_B", "back-deuce");
    return RallyMateScoreEngine.replay(events, rmAdvantageFormat())["display"].equals("40 - 40");
}

(:test)
function testUndoTargetsOnlyLatestActivePoint(logger) {
    var events = [];
    rmTestPoint(events, "POINT_TEAM_A", "p1");
    rmTestPoint(events, "POINT_TEAM_B", "p2");
    events.add({"id" => "u1", "type" => "UNDO", "target" => "p2"});
    var score = RallyMateScoreEngine.replay(events, rmAdvantageFormat());
    return score["display"].equals("15 - 0");
}

(:test)
function testFreshWatchAcceptsPhoneMatchWithoutGhostEvents(logger) {
    Storage.deleteValue(RM_STATE_KEY);
    var model = new RallyMateScoreModel();
    model.restore();
    Test.assertEqualMessage(0, model.pendingCount(), "l'avvio ha creato un match fantasma");
    var accepted = model.startMatch("phone-match-1234", rmAdvantageFormat(), null);
    var valid = accepted
        && model.matchId().equals("phone-match-1234")
        && model.pendingCount() == 1;
    Storage.deleteValue(RM_STATE_KEY);
    return valid;
}

(:test)
function testPendingStandaloneMatchCannotBeOverwritten(logger) {
    Storage.deleteValue(RM_STATE_KEY);
    var model = new RallyMateScoreModel();
    model.restore();
    Test.assert(model.appendPoint("POINT_TEAM_A", "TAP"));
    var originalMatch = model.matchId();
    var accepted = model.startMatch("replacement-1234", rmAdvantageFormat(), null);
    var valid = !accepted
        && model.matchId().equals(originalMatch)
        && model.pendingCount() == 2;
    Storage.deleteValue(RM_STATE_KEY);
    return valid;
}

(:test)
function testAtomicFirstPointUsesUniqueEventIds(logger) {
    Storage.deleteValue(RM_STATE_KEY);
    var model = new RallyMateScoreModel();
    model.restore();
    Test.assert(model.appendPoint("POINT_TEAM_A", "TAP"));
    var pending = model.pendingEvents();
    var valid = pending.size() == 2
        && !pending[0]["id"].equals(pending[1]["id"])
        && rmIsUuidV4(pending[0]["id"])
        && rmIsUuidV4(pending[1]["id"])
        && pending[0]["type"].equals("MATCH_STARTED")
        && pending[1]["type"].equals("POINT_TEAM_A");
    Storage.deleteValue(RM_STATE_KEY);
    return valid;
}

(:test)
function testMalformedFormatFallsBackToSafeDefaults(logger) {
    var normalized = RallyMateScoreEngine.normalizedFormat({
        "setsToWin" => -4,
        "gamesPerSet" => "six",
        "goldenPoint" => "yes",
        "tieBreakPoints" => 9
    });
    return normalized["setsToWin"] == 2
        && normalized["gamesPerSet"] == 6
        && normalized["goldenPoint"] == false
        && normalized["tieBreakPoints"] == 9;
}

(:test)
function testStraightSetCompletesAtSixGames(logger) {
    var events = [];
    var id = 0;
    for (var setIndex = 0; setIndex < 2; setIndex += 1) {
        for (var game = 0; game < 6; game += 1) {
            for (var point = 0; point < 4; point += 1) {
                rmTestPoint(events, "POINT_TEAM_A", "s" + id.toString());
                id += 1;
            }
        }
    }
    var score = RallyMateScoreEngine.replay(events, rmAdvantageFormat());
    return score["complete"] == true && score["setsA"] == 2 && score["setsB"] == 0;
}

(:test)
function testTiebreakRequiresTwoPointMargin(logger) {
    var events = [];
    var id = 0;
    for (var game = 0; game < 6; game += 1) {
        for (var a = 0; a < 4; a += 1) {
            rmTestPoint(events, "POINT_TEAM_A", "ta" + id.toString());
            id += 1;
        }
        for (var b = 0; b < 4; b += 1) {
            rmTestPoint(events, "POINT_TEAM_B", "tb" + id.toString());
            id += 1;
        }
    }
    for (var tied = 0; tied < 6; tied += 1) {
        rmTestPoint(events, "POINT_TEAM_A", "tca" + id.toString());
        id += 1;
        rmTestPoint(events, "POINT_TEAM_B", "tcb" + id.toString());
        id += 1;
    }
    rmTestPoint(events, "POINT_TEAM_A", "lead7");
    Test.assertEqualMessage("7 - 6", RallyMateScoreEngine.replay(events, rmAdvantageFormat())["display"], "tiebreak chiuso senza margine");
    rmTestPoint(events, "POINT_TEAM_A", "win8");
    var score = RallyMateScoreEngine.replay(events, rmAdvantageFormat());
    return score["setsA"] == 1 && score["gamesA"] == 0 && score["tiebreak"] == false;
}

(:test)
function testGoldenPointClosesDeuceImmediately(logger) {
    var events = [];
    for (var i = 0; i < 3; i += 1) {
        rmTestPoint(events, "POINT_TEAM_A", "ga" + i.toString());
        rmTestPoint(events, "POINT_TEAM_B", "gb" + i.toString());
    }
    var format = RallyMateScoreEngine.defaultFormat();
    format["goldenPoint"] = true;
    format["setsToWin"] = 1;
    format["gamesPerSet"] = 1;
    rmTestPoint(events, "POINT_TEAM_A", "golden-winner");
    var score = RallyMateScoreEngine.replay(events, format);
    return score["gamesA"] == 1 && score["pointsA"] == 0 && score["pointsB"] == 0;
}

(:test)
function testSingleSetFormatStopsAfterOneSet(logger) {
    var events = [];
    var format = RallyMateScoreEngine.defaultFormat();
    format["setsToWin"] = 1;
    format["gamesPerSet"] = 1;
    // Anche un set custom da un game conserva il margine regolamentare di
    // due game: 2-0 chiude il set, 1-0 no.
    for (var i = 0; i < 8; i += 1) {
        rmTestPoint(events, "POINT_TEAM_B", "single" + i.toString());
    }
    var score = RallyMateScoreEngine.replay(events, format);
    return score["complete"] == true && score["setsB"] == 1;
}

(:test)
function testAssignedTeamRejectsOpponentPoints(logger) {
    Storage.deleteValue(RM_STATE_KEY);
    var model = new RallyMateScoreModel();
    if (!model.startMatch("match-duo-garmin", rmAdvantageFormat(), "TEAM_A")) {
        return false;
    }
    var rejected = model.appendPoint("POINT_TEAM_B", "TAP");
    var accepted = model.appendPoint("POINT_TEAM_A", "TAP");
    var valid = rejected == false && accepted == true && model.score()["display"].equals("15 - 0");
    Storage.deleteValue(RM_STATE_KEY);
    return valid;
}

(:test)
function testUndoAvailabilityTracksActivePoint(logger) {
    Storage.deleteValue(RM_STATE_KEY);
    var model = new RallyMateScoreModel();
    model.restore();
    Test.assertEqualMessage(false, model.canUndo(), "undo attivo senza punti");
    Test.assert(model.appendPoint("POINT_TEAM_A", "TAP"));
    Test.assertEqualMessage(true, model.canUndo(), "undo non attivo dopo il punto");
    Test.assert(model.appendUndo("TAP"));
    var valid = model.canUndo() == false;
    Storage.deleteValue(RM_STATE_KEY);
    return valid;
}

(:test)
function testPauseResumeAndManualFinishAreReplayable(logger) {
    Storage.deleteValue(RM_STATE_KEY);
    var model = new RallyMateScoreModel();
    model.restore();
    Test.assert(model.startLocalMatch("ADV_BO3"));
    Test.assert(model.appendPoint("POINT_TEAM_A", "TAP"));
    Test.assert(model.pauseMatch());
    Test.assertEqualMessage(true, model.score()["paused"], "pausa non ricostruita");
    Test.assertEqualMessage(false, model.appendPoint("POINT_TEAM_A", "TAP"), "punto accettato in pausa");
    Test.assert(model.resumeMatch());
    Test.assertEqualMessage(false, model.score()["paused"], "ripresa non ricostruita");
    Test.assert(model.finishMatch());
    var valid = model.score()["complete"] == true
        && model.pendingCount() == 5;
    Storage.deleteValue(RM_STATE_KEY);
    return valid;
}

(:test)
function testPausedPointAndUndoAreNoOpsDuringReplay(logger) {
    var events = [
        {"id" => "start", "type" => "MATCH_STARTED", "target" => null},
        {"id" => "point-a", "type" => "POINT_TEAM_A", "target" => null},
        {"id" => "pause", "type" => "MATCH_PAUSED", "target" => null},
        {"id" => "paused-point", "type" => "POINT_TEAM_B", "target" => null},
        {"id" => "paused-undo", "type" => "UNDO", "target" => "point-a"},
        {"id" => "resume", "type" => "MATCH_RESUMED", "target" => null},
        {"id" => "point-b", "type" => "POINT_TEAM_B", "target" => null},
        {"id" => "valid-undo", "type" => "UNDO", "target" => "point-b"}
    ];
    var score = RallyMateScoreEngine.replay(events, rmAdvantageFormat());
    return score["paused"] == false && score["display"].equals("15 - 0");
}

(:test)
function testPausedModelRejectsUndoWithoutLoggingIt(logger) {
    Storage.deleteValue(RM_STATE_KEY);
    var model = new RallyMateScoreModel();
    model.restore();
    Test.assert(model.startLocalMatch("ADV_BO3"));
    Test.assert(model.appendPoint("POINT_TEAM_A", "TAP"));
    Test.assert(model.pauseMatch());
    var pendingBefore = model.pendingCount();
    var valid = model.appendUndo("TAP") == false
        && model.pendingCount() == pendingBefore
        && model.score()["display"].equals("15 - 0");
    Storage.deleteValue(RM_STATE_KEY);
    return valid;
}

(:test)
function testTouchLayoutScoresOnlyInsideVisibleControls(logger) {
    var layout = RallyMateLayout.create(390, 390, false, true);
    var scoreCardTap = RallyMateLayout.actionFor(layout, 195, 100, null, false, false, false);
    var leftTap = RallyMateLayout.actionFor(layout, layout["teamAX"] + 3, layout["buttonY"] + 3, null, false, false, false);
    var rightTap = RallyMateLayout.actionFor(layout, layout["teamBX"] + 3, layout["buttonY"] + 3, null, false, false, false);
    var gapTap = RallyMateLayout.actionFor(
        layout,
        layout["teamAX"] + layout["teamAW"] + 1,
        layout["buttonY"] + 3,
        null,
        false,
        false,
        false
    );
    return scoreCardTap == null
        && leftTap.equals("POINT_TEAM_A")
        && rightTap.equals("POINT_TEAM_B")
        && gapTap == null;
}

(:test)
function testTouchLayoutSupportsDuoAndUndo(logger) {
    var layout = RallyMateLayout.create(176, 176, true, true);
    var duoTap = RallyMateLayout.actionFor(
        layout,
        layout["buttonX"] + layout["buttonW"] / 2,
        layout["buttonY"] + 2,
        "TEAM_B",
        false,
        true,
        false
    );
    var undoTap = RallyMateLayout.actionFor(
        layout,
        layout["undoX"] + 2,
        layout["footerY"] + 2,
        "TEAM_B",
        false,
        true,
        false
    );
    var completedTap = RallyMateLayout.actionFor(
        layout,
        layout["buttonX"] + 2,
        layout["buttonY"] + 2,
        "TEAM_B",
        true,
        true,
        false
    );
    var pausedTap = RallyMateLayout.actionFor(
        layout,
        layout["buttonX"] + 2,
        layout["buttonY"] + 2,
        null,
        false,
        false,
        true
    );
    var menuTap = RallyMateLayout.actionFor(
        layout,
        layout["syncX"] + 2,
        layout["footerY"] + 2,
        null,
        false,
        false,
        false
    );
    return duoTap.equals("POINT_TEAM_B")
        && undoTap.equals("UNDO")
        && completedTap == null
        && pausedTap.equals("MENU")
        && menuTap.equals("MENU");
}

(:test)
function testCompactFooterIsSymmetric(logger) {
    var layout = RallyMateLayout.create(176, 176, true, true);
    return layout["undoW"] == layout["syncW"]
        && layout["syncX"] > layout["undoX"] + layout["undoW"]
        && layout["undoX"] >= 26
        && layout["syncX"] + layout["syncW"] <= 150;
}

(:test)
function testRetryBackoffCapsWithoutAggressivePolling(logger) {
    return RallyMateEnergyPolicy.retryDelay(0) == 5000
        && RallyMateEnergyPolicy.retryDelay(1) == 15000
        && RallyMateEnergyPolicy.retryDelay(2) == 30000
        && RallyMateEnergyPolicy.retryDelay(3) == 60000
        && RallyMateEnergyPolicy.retryDelay(8) == 120000;
}

(:test)
function testActivityPolicyTreatsOnlyOffOrMissingTimerAsIdle(logger) {
    return RallyMateActivityPolicy.isIdle(null)
        && RallyMateActivityPolicy.isIdle(Activity.TIMER_STATE_OFF)
        && !RallyMateActivityPolicy.isIdle(Activity.TIMER_STATE_ON)
        && !RallyMateActivityPolicy.isIdle(Activity.TIMER_STATE_PAUSED)
        && !RallyMateActivityPolicy.isIdle(Activity.TIMER_STATE_STOPPED);
}

(:test)
function testRealAppExitFinalizesOwnedActivity(logger) {
    return RallyMateActivityPolicy.shouldFinalizeOnStop(null)
        && RallyMateActivityPolicy.shouldFinalizeOnStop({})
        && RallyMateActivityPolicy.shouldFinalizeOnStop({:suspend => false});
}

(:test)
function testSystemSuspensionKeepsOwnedActivityResumable(logger) {
    return !RallyMateActivityPolicy.shouldFinalizeOnStop({:suspend => true});
}

(:test)
function testActivityOwnershipRequiresSameMatchAndStartTime(logger) {
    var owner = {
        "matchId" => "garmin-match-1234",
        "startSeconds" => 1000
    };
    return RallyMateActivityPolicy.canRecover(owner, "garmin-match-1234", 1007)
        && !RallyMateActivityPolicy.canRecover(owner, "other-match-1234", 1007)
        && !RallyMateActivityPolicy.canRecover(owner, "garmin-match-1234", 1015);
}

(:test)
function testActivityOwnershipRejectsIncompleteEvidence(logger) {
    return !RallyMateActivityPolicy.canRecover({}, "garmin-match-1234", 1000)
        && !RallyMateActivityPolicy.canRecover(
            {"matchId" => "garmin-match-1234", "startSeconds" => 1000},
            "garmin-match-1234",
            null
        );
}

(:test)
function testRecordingModeDefaultsToRallyMateManaged(logger) {
    return RallyMateRecordingPolicy.normalizeMode(null).equals(RM_MODE_RALLYMATE)
        && RallyMateRecordingPolicy.normalizeMode("NONSENSE").equals(RM_MODE_RALLYMATE)
        && RallyMateRecordingPolicy.normalizeMode(RM_MODE_EXTERNAL).equals(RM_MODE_EXTERNAL)
        && RallyMateRecordingPolicy.normalizeMode(RM_MODE_DISABLED).equals(RM_MODE_DISABLED);
}

(:test)
function testRecordingStartAllowedOnceThenRefusedAsDuplicate(logger) {
    return RallyMateRecordingPolicy
            .startDecision(RM_MODE_RALLYMATE, RM_STATE_IDLE, false)
            .equals(RM_START_ALLOWED)
        && RallyMateRecordingPolicy
            .startDecision(RM_MODE_RALLYMATE, RM_STATE_OWNED, false)
            .equals(RM_START_DUPLICATE);
}

(:test)
function testRecordingNeverAutoRestartsAfterTerminalState(logger) {
    return RallyMateRecordingPolicy
            .startDecision(RM_MODE_RALLYMATE, RM_STATE_EXTERNAL, false)
            .equals(RM_START_SUPPRESSED)
        && RallyMateRecordingPolicy
            .startDecision(RM_MODE_RALLYMATE, RM_STATE_SAVED, false)
            .equals(RM_START_SUPPRESSED)
        && RallyMateRecordingPolicy
            .startDecision(RM_MODE_RALLYMATE, RM_STATE_FAILED, false)
            .equals(RM_START_SUPPRESSED)
        && RallyMateRecordingPolicy
            .startDecision(RM_MODE_RALLYMATE, RM_STATE_EXTERNAL, true)
            .equals(RM_START_ALLOWED);
}

(:test)
function testRecordingUserChoiceKeepsPadelandiaOutOfTheSession(logger) {
    return RallyMateRecordingPolicy
            .startDecision(RM_MODE_EXTERNAL, RM_STATE_IDLE, false)
            .equals(RM_START_EXTERNAL)
        && RallyMateRecordingPolicy
            .startDecision(RM_MODE_EXTERNAL, RM_STATE_IDLE, true)
            .equals(RM_START_EXTERNAL)
        && RallyMateRecordingPolicy
            .startDecision(RM_MODE_DISABLED, RM_STATE_IDLE, true)
            .equals(RM_START_DISABLED);
}

(:test)
function testResumableTerminalStatusAlwaysWins(logger) {
    var paused = {
        "matchId" => "m1", "status" => RM_STATUS_PAUSED,
        "stateVersion" => 9, "updatedAt" => 200
    };
    var completed = {
        "matchId" => "m1", "status" => RM_STATUS_COMPLETED,
        "stateVersion" => 3, "updatedAt" => 100
    };
    return RallyMateResumablePolicy.winner(paused, completed)["status"]
            .equals(RM_STATUS_COMPLETED)
        && RallyMateResumablePolicy.winner(completed, paused)["status"]
            .equals(RM_STATUS_COMPLETED);
}

(:test)
function testResumableOlderVersionNeverOverwritesNewer(logger) {
    var newer = {
        "matchId" => "m1", "status" => RM_STATUS_IN_PROGRESS,
        "stateVersion" => 12, "updatedAt" => 50
    };
    var older = {
        "matchId" => "m1", "status" => RM_STATUS_PAUSED,
        "stateVersion" => 4, "updatedAt" => 100
    };
    var merged = RallyMateResumablePolicy.merge([newer], older);
    return merged.size() == 1
        && merged[0]["stateVersion"] == 12
        && merged[0]["status"].equals(RM_STATUS_IN_PROGRESS);
}

(:test)
function testResumableListIsOrderedByLastActivity(logger) {
    var list = RallyMateResumablePolicy.sortByUpdatedAt([
        {"matchId" => "old", "status" => RM_STATUS_PAUSED, "updatedAt" => 10},
        {"matchId" => "new", "status" => RM_STATUS_PAUSED, "updatedAt" => 90}
    ]);
    return list[0]["matchId"].equals("new") && list[1]["matchId"].equals("old");
}

(:test)
function testResumableFiltersOutTerminalMatches(logger) {
    var only = RallyMateResumablePolicy.resumableOnly([
        {"matchId" => "a", "status" => RM_STATUS_PAUSED, "updatedAt" => 1},
        {"matchId" => "b", "status" => RM_STATUS_COMPLETED, "updatedAt" => 2},
        {"matchId" => "c", "status" => RM_STATUS_ABANDONED, "updatedAt" => 3}
    ]);
    return only.size() == 1 && only[0]["matchId"].equals("a");
}

(:test)
function testResumableStatusForActionMapping(logger) {
    return RallyMateResumablePolicy.statusForAction("PAUSED").equals(RM_STATUS_PAUSED)
        && RallyMateResumablePolicy.statusForAction("COMPLETED").equals(RM_STATUS_COMPLETED)
        && RallyMateResumablePolicy.statusForAction("RESUMED").equals(RM_STATUS_IN_PROGRESS)
        && RallyMateResumablePolicy.normalizeStatus("NONSENSE").equals(RM_STATUS_IN_PROGRESS);
}

(:test)
function testResumeRejectionAlwaysProducesAMessage(logger) {
    // Unknown or missing reasons must still say something to the user.
    return RallyMateResumeRejection.messageFor("journal_unsupported")
            == Rez.Strings.ResumeNotOnWatch
        && RallyMateResumeRejection.messageFor("not_resumable")
            == Rez.Strings.ResumeAlreadyClosed
        && RallyMateResumeRejection.messageFor("transport_failed")
            == Rez.Strings.ResumeFailed
        && RallyMateResumeRejection.messageFor(null)
            == Rez.Strings.ResumeFailed;
}
