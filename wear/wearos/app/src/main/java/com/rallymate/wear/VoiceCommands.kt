package com.rallymate.wear

import java.text.Normalizer
import java.util.Locale

internal enum class VoiceWatchCommand {
    POINT_US,
    POINT_THEM,
    UNDO,
    BLIND_MODE,
    PAUSE,
    RESUME,
    FINISH,
}

internal fun parseVoiceCommand(text: String): VoiceWatchCommand? {
    val normalized = Normalizer.normalize(text, Normalizer.Form.NFD)
        .replace("\\p{M}+".toRegex(), "")
        .lowercase(Locale.ITALIAN)
        .trim()
    if (normalized.isBlank()) return null
    if (normalized == "noi" || normalized == "team a") return VoiceWatchCommand.POINT_US
    if (normalized == "loro" || normalized == "team b") return VoiceWatchCommand.POINT_THEM
    if (normalized == "pausa") return VoiceWatchCommand.PAUSE
    if (normalized == "riprendi") return VoiceWatchCommand.RESUME
    if (
        normalized == "termina partita" ||
        normalized == "fine partita"
    ) return VoiceWatchCommand.FINISH
    if (
        normalized.contains("annulla") ||
        normalized.contains("indietro") ||
        normalized.contains("cancella") ||
        normalized.contains("correggi")
    ) return VoiceWatchCommand.UNDO
    if (
        normalized.contains("blind") ||
        normalized.contains("cieco") ||
        normalized.contains("schermo spento")
    ) return VoiceWatchCommand.BLIND_MODE
    if (
        normalized.contains("metti in pausa") ||
        normalized.contains("ferma partita")
    ) return VoiceWatchCommand.PAUSE
    if (
        normalized.contains("riprendi partita") ||
        normalized.contains("continua partita")
    ) return VoiceWatchCommand.RESUME
    if (
        normalized.contains("termina") ||
        normalized.contains("concludi") ||
        normalized.contains("finisci partita")
    ) return VoiceWatchCommand.FINISH
    if (
        normalized.contains("team a") ||
        normalized.contains("punto noi") ||
        normalized.contains("punto mio") ||
        normalized.contains("a noi") ||
        normalized.contains("per noi") ||
        normalized.contains("nostro") ||
        normalized.contains("nostri")
    ) return VoiceWatchCommand.POINT_US
    if (
        normalized.contains("team b") ||
        normalized.contains("punto loro") ||
        normalized.contains("punto avversario") ||
        normalized.contains("a loro") ||
        normalized.contains("per loro") ||
        normalized.contains("avversari") ||
        normalized.contains("avversario")
    ) return VoiceWatchCommand.POINT_THEM
    return null
}
