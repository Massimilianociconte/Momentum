package com.rallymate.wear

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class VoiceCommandsTest {
    @Test
    fun parsesShortItalianScoringCommands() {
        assertEquals(VoiceWatchCommand.POINT_US, parseVoiceCommand("Noi"))
        assertEquals(VoiceWatchCommand.POINT_THEM, parseVoiceCommand("Loro"))
        assertEquals(VoiceWatchCommand.POINT_US, parseVoiceCommand("Team A"))
        assertEquals(VoiceWatchCommand.POINT_THEM, parseVoiceCommand("Team B"))
        assertEquals(VoiceWatchCommand.POINT_US, parseVoiceCommand("punto noi"))
        assertEquals(VoiceWatchCommand.POINT_US, parseVoiceCommand("punto mio"))
        assertEquals(VoiceWatchCommand.POINT_THEM, parseVoiceCommand("punto loro"))
        assertEquals(VoiceWatchCommand.UNDO, parseVoiceCommand("annulla"))
        assertEquals(VoiceWatchCommand.BLIND_MODE, parseVoiceCommand("modalità cieco"))
        assertEquals(VoiceWatchCommand.PAUSE, parseVoiceCommand("pausa"))
        assertEquals(VoiceWatchCommand.RESUME, parseVoiceCommand("riprendi"))
        assertEquals(VoiceWatchCommand.FINISH, parseVoiceCommand("termina partita"))
    }

    @Test
    fun rejectsUnrelatedSpeech() {
        assertNull(parseVoiceCommand("che bella giornata"))
    }
}
