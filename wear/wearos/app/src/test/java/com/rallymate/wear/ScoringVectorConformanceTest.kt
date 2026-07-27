package com.rallymate.wear

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Conformità cross-piattaforma: rigioca i vettori generati dall'engine Dart
 * (wear/shared/scoring_vectors.json, contratto canonico) su questo engine e
 * confronta lo snapshot dopo ogni operazione.
 *
 * Rigenerare i vettori con:
 *   cd packages/momentum_core && dart run tool/generate_scoring_vectors.dart
 */
class ScoringVectorConformanceTest {

    private fun vectorsFile(): File {
        var dir: File? = File(System.getProperty("user.dir")!!)
        while (dir != null) {
            val candidate = File(dir, "wear/shared/scoring_vectors.json")
            if (candidate.isFile) return candidate
            dir = dir.parentFile
        }
        throw AssertionError("wear/shared/scoring_vectors.json non trovato")
    }

    private fun label(state: MatchState, freePlay: Boolean, team: TeamId): String =
        when {
            freePlay ->
                (if (team == TeamId.A) state.freePlayA else state.freePlayB).toString()
            state.inTieBreak || state.inSuperTieBreak ->
                (if (team == TeamId.A) state.tieBreakA else state.tieBreakB).toString()
            else -> state.pointsLabel(team)
        }

    private fun optWire(json: JSONObject, key: String): String? =
        if (json.isNull(key)) null else json.getString(key)

    private fun assertSnapshot(
        engine: ScoringEngine,
        freePlay: Boolean,
        expect: JSONObject,
        context: String,
    ) {
        val s = engine.state
        assertEquals("$context completed", expect.getBoolean("completed"), s.completed)
        assertEquals("$context paused", expect.getBoolean("paused"), s.paused)
        assertEquals("$context winner", optWire(expect, "winner"), s.winner?.wire)
        assertEquals("$context setsA", expect.getInt("setsA"), s.setsA)
        assertEquals("$context setsB", expect.getInt("setsB"), s.setsB)
        assertEquals("$context gamesA", expect.getInt("gamesA"), s.gamesA)
        assertEquals("$context gamesB", expect.getInt("gamesB"), s.gamesB)
        assertEquals("$context labelA", expect.getString("labelA"), label(s, freePlay, TeamId.A))
        assertEquals("$context labelB", expect.getString("labelB"), label(s, freePlay, TeamId.B))
        assertEquals(
            "$context advantage",
            optWire(expect, "advantage"),
            s.advantage?.wire,
        )
        assertEquals("$context deuceNumber", expect.getInt("deuceNumber"), s.deuceNumber)
        assertEquals("$context isStarPoint", expect.getBoolean("isStarPoint"), s.starPointActive)
        assertEquals("$context inTieBreak", expect.getBoolean("inTieBreak"), s.inTieBreak)
        assertEquals(
            "$context inSuperTieBreak",
            expect.getBoolean("inSuperTieBreak"),
            s.inSuperTieBreak,
        )
        assertEquals("$context tieBreakA", expect.getInt("tieBreakA"), s.tieBreakA)
        assertEquals("$context tieBreakB", expect.getInt("tieBreakB"), s.tieBreakB)
        assertEquals("$context freePlayA", expect.getInt("freePlayA"), s.freePlayA)
        assertEquals("$context freePlayB", expect.getInt("freePlayB"), s.freePlayB)

        val expectedSets = expect.getJSONArray("completedSets")
        assertEquals(
            "$context completedSets.length",
            expectedSets.length(),
            s.completedSets.size,
        )
        for (i in 0 until expectedSets.length()) {
            val set = expectedSets.getJSONObject(i)
            val actual = s.completedSets[i]
            assertEquals("$context set[$i].gamesA", set.getInt("gamesA"), actual.gamesA)
            assertEquals("$context set[$i].gamesB", set.getInt("gamesB"), actual.gamesB)
            val tbA = if (set.isNull("tieBreakA")) null else set.getInt("tieBreakA")
            val tbB = if (set.isNull("tieBreakB")) null else set.getInt("tieBreakB")
            assertEquals("$context set[$i].tieBreakA", tbA, actual.tieBreakA)
            assertEquals("$context set[$i].tieBreakB", tbB, actual.tieBreakB)
            assertEquals(
                "$context set[$i].superTieBreak",
                set.getBoolean("superTieBreak"),
                actual.isSuperTieBreak,
            )
        }
    }

    @Test
    fun engineMatchesEveryDartVector() {
        val document = JSONObject(vectorsFile().readText())
        val vectors = document.getJSONArray("vectors")
        var executed = 0

        for (v in 0 until vectors.length()) {
            val vector = vectors.getJSONObject(v)
            val platforms = vector.getJSONArray("platforms")
            if (!platforms.contains("kotlin")) continue
            executed++

            val id = vector.getString("id")
            val format = MatchFormat.fromJson(vector.getJSONObject("format"))
            var tick = 0L
            val engine = ScoringEngine(
                matchId = "vec_$id",
                format = format,
                clock = { 1750000000000 + (++tick) * 1000 },
                idGen = { "evt_${id}_${++tick}" },
            )
            engine.start()

            val steps = vector.getJSONArray("steps")
            for (i in 0 until steps.length()) {
                val step = steps.getJSONObject(i)
                val team = optWire(step, "team")?.let(TeamId::fromWire)
                when (val op = step.getString("op")) {
                    "point" -> engine.addPoint(team!!)
                    "edit" -> engine.loadEvents(
                        engine.allEvents + MatchEvent(
                            eventId = "evt_${id}_edit_$i",
                            matchId = "vec_$id",
                            timestampMs = 1_760_000_000_000 + i,
                            type = EventType.SCORE_EDITED,
                            sourceMethod = "MANUAL_EDIT",
                            payload = step.getJSONObject("payload"),
                        ),
                    )
                    "undo" -> engine.undo(team)
                    "pause" -> engine.pause()
                    "resume" -> engine.resume()
                    "finish" -> engine.finish(team)
                    else -> throw AssertionError("Operazione sconosciuta: $op")
                }
                assertSnapshot(
                    engine,
                    format.freePlay,
                    step.getJSONObject("expect"),
                    "$id#$i",
                )
            }
        }
        assertTrue("Nessun vettore kotlin eseguito", executed > 0)
    }

    private fun JSONArray.contains(value: String): Boolean {
        for (i in 0 until length()) if (getString(i) == value) return true
        return false
    }
}
