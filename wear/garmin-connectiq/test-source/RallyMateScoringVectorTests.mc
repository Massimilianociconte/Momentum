// Conformità cross-piattaforma dello scoring: rigioca i vettori generati da
// rally_core (wear/shared/scoring_vectors.json, proiettati per Connect IQ da
// generate_scoring_vectors.dart) sull'engine Monkey C e confronta lo snapshot
// dopo OGNI passo. Il contratto è l'engine Dart, esattamente come per i runner
// Kotlin (Wear OS), Swift (watchOS) e JavaScript (Fitbit OS).
//
// Layout di uno step (tupla posizionale, vedi il generatore):
//   [op, team, completed, paused, setsA, setsB, gamesA, gamesB,
//    labelA, labelB, inTieBreak, inSuperTieBreak]
// op: "p" punto · "u" undo · "P" pausa · "R" ripresa · "f" fine manuale
// team: "A" | "B" | null
import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

const RM_VEC_OP = 0;
const RM_VEC_TEAM = 1;
const RM_VEC_COMPLETED = 2;
const RM_VEC_PAUSED = 3;
const RM_VEC_SETS_A = 4;
const RM_VEC_SETS_B = 5;
const RM_VEC_GAMES_A = 6;
const RM_VEC_GAMES_B = 7;
const RM_VEC_LABEL_A = 8;
const RM_VEC_LABEL_B = 9;
const RM_VEC_TIEBREAK = 10;
const RM_VEC_SUPER_TIEBREAK = 11;

function rmVectorDocument() {
    return Application.loadResource(Rez.JsonData.RallyMateScoringVectors);
}

// L'engine espone un solo "display" combinato: per confrontarlo con labelA e
// labelB dei vettori lo si rispezza sul separatore usato da formatState.
function rmSplitDisplay(display) {
    var separator = display.find(" - ");
    if (separator == null) {
        return null;
    }
    return [
        display.substring(0, separator),
        display.substring(separator + 3, display.length())
    ];
}

// Applica uno step al journal. Ritorna il journal aggiornato.
//
// L'undo NON ricalcola il bersaglio nel test: usa
// RallyMateScoreEngine.lastUndoableEventIdIn, la stessa regola del modello a
// runtime. Una seconda implementazione qui proverebbe solo se stessa.
function rmApplyVectorStep(events, step, index) {
    var op = step[RM_VEC_OP];
    var team = step[RM_VEC_TEAM];
    var id = "vec-" + index.toString();

    if (op.equals("p")) {
        events.add({
            "id" => id,
            "type" => team.equals("A") ? "POINT_TEAM_A" : "POINT_TEAM_B",
            "target" => null
        });
    } else if (op.equals("u")) {
        var assignedTeam = team == null ? null : "TEAM_" + team;
        var target = RallyMateScoreEngine.lastUndoableEventIdIn(events, assignedTeam);
        // Nessun punto annullabile: l'undo è un no-op anche sul telefono, quindi
        // non entra nel journal.
        if (target != null) {
            events.add({"id" => id, "type" => "UNDO", "target" => target});
        }
    } else if (op.equals("P")) {
        events.add({"id" => id, "type" => "MATCH_PAUSED", "target" => null});
    } else if (op.equals("R")) {
        events.add({"id" => id, "type" => "MATCH_RESUMED", "target" => null});
    } else if (op.equals("f")) {
        events.add({
            "id" => id,
            "type" => "MATCH_COMPLETED",
            "target" => null,
            "sourceMethod" => "MANUAL_EDIT"
        });
    } else {
        Test.assertMessage(false, "operazione sconosciuta: " + op);
    }
    return events;
}

function rmAssertVectorSnapshot(state, step, context) {
    Test.assertEqualMessage(
        step[RM_VEC_COMPLETED], state["complete"] == true, context + " completed"
    );
    Test.assertEqualMessage(
        step[RM_VEC_PAUSED], state["paused"] == true, context + " paused"
    );
    Test.assertEqualMessage(step[RM_VEC_SETS_A], state["setsA"], context + " setsA");
    Test.assertEqualMessage(step[RM_VEC_SETS_B], state["setsB"], context + " setsB");
    Test.assertEqualMessage(step[RM_VEC_GAMES_A], state["gamesA"], context + " gamesA");
    Test.assertEqualMessage(step[RM_VEC_GAMES_B], state["gamesB"], context + " gamesB");
    Test.assertEqualMessage(
        step[RM_VEC_TIEBREAK] || step[RM_VEC_SUPER_TIEBREAK],
        state["tiebreak"] == true,
        context + " inTieBreak"
    );
    Test.assertEqualMessage(
        step[RM_VEC_SUPER_TIEBREAK],
        state["superTiebreak"] == true,
        context + " inSuperTieBreak"
    );

    // A match concluso il display passa ai set: le label per-team non sono più
    // rappresentate, esattamente come sul telefono.
    if (step[RM_VEC_COMPLETED] == true) {
        return;
    }
    var labels = rmSplitDisplay(state["display"]);
    Test.assertMessage(labels != null, context + " display non separabile");
    Test.assertEqualMessage(step[RM_VEC_LABEL_A], labels[0], context + " labelA");
    Test.assertEqualMessage(step[RM_VEC_LABEL_B], labels[1], context + " labelB");
}

// Rigioca i vettori con indice in [from, to) e ritorna quanti ne ha eseguiti.
function rmRunVectorRange(from, to) {
    var vectors = rmVectorDocument()["vectors"];
    var executed = 0;
    for (var v = from; v < to && v < vectors.size(); v += 1) {
        var vector = vectors[v];
        var format = RallyMateScoreEngine.normalizedFormat(vector["format"]);
        var steps = vector["steps"];
        var events = [];
        for (var s = 0; s < steps.size(); s += 1) {
            var step = steps[s];
            events = rmApplyVectorStep(events, step, s);
            // Snapshot dopo ogni passo: il contratto è il replay completo del
            // journal, non l'applicazione incrementale.
            var state = RallyMateScoreEngine.replay(events, format);
            rmAssertVectorSnapshot(
                state, step, vector["id"] + " step " + s.toString()
            );
        }
        executed += 1;
    }
    return executed;
}

(:test)
function testSharedScoringVectorsBatch1(logger) {
    return rmRunVectorRange(0, 6) == 6;
}

(:test)
function testSharedScoringVectorsBatch2(logger) {
    return rmRunVectorRange(6, 12) == 6;
}

(:test)
function testSharedScoringVectorsBatch3(logger) {
    return rmRunVectorRange(12, 18) == 6;
}

// Guardia sul contenuto della risorsa: se il generatore cambia proiezione o
// qualcuno committa un file troncato, i batch sopra "passerebbero" a vuoto.
(:test)
function testSharedScoringVectorsResourceIsComplete(logger) {
    var document = rmVectorDocument();
    var vectors = document["vectors"];
    Test.assertEqualMessage(
        18, vectors.size(), "numero di vettori Garmin atteso"
    );
    for (var v = 0; v < vectors.size(); v += 1) {
        var vector = vectors[v];
        Test.assertMessage(
            vector["id"] != null && vector["id"].length() > 0,
            "vettore senza id all'indice " + v.toString()
        );
        Test.assertMessage(
            vector["steps"].size() > 0,
            "vettore senza step: " + vector["id"]
        );
        Test.assertMessage(
            vector["format"]["setsToWin"] != null,
            "formato incompleto: " + vector["id"]
        );
    }
    return true;
}
