import Foundation

enum WatchVoiceCommand: Equatable {
    case pointUs
    case pointThem
    case undo
    case blindMode
    case pause
    case resume
    case finish

    var label: String {
        switch self {
        case .pointUs: "Noi"
        case .pointThem: "Loro"
        case .undo: "Annulla"
        case .blindMode: "Modalita rapida"
        case .pause: "Pausa"
        case .resume: "Riprendi"
        case .finish: "Termina partita"
        }
    }

    struct Match: Equatable {
        let command: WatchVoiceCommand
        let requiresConfirmation: Bool
        let normalizedText: String
    }

    static func parse(_ text: String) -> WatchVoiceCommand? {
        match(text)?.command
    }

    static func match(_ text: String) -> Match? {
        let folded = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "it_IT")
        ).lowercased()
        let value = folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        let exact: [String: WatchVoiceCommand] = [
            "noi": .pointUs,
            "team a": .pointUs,
            "loro": .pointThem,
            "team b": .pointThem,
            "annulla": .undo,
            "pausa": .pause,
            "riprendi": .resume,
            "termina partita": .finish,
            "fine partita": .finish,
            "modalita rapida": .blindMode,
        ]
        if let command = exact[value] {
            return Match(
                command: command,
                requiresConfirmation: command == .finish,
                normalizedText: value
            )
        }

        if ["metti in pausa", "ferma partita"].contains(where: value.contains) {
            return Match(command: .pause, requiresConfirmation: true, normalizedText: value)
        }
        if ["continua partita", "riprendi partita"].contains(where: value.contains) {
            return Match(command: .resume, requiresConfirmation: true, normalizedText: value)
        }
        if ["termina", "concludi", "finisci partita"].contains(where: value.contains) {
            return Match(command: .finish, requiresConfirmation: true, normalizedText: value)
        }
        if ["annulla", "indietro", "cancella", "correggi"].contains(where: value.contains) {
            return Match(command: .undo, requiresConfirmation: true, normalizedText: value)
        }
        if ["blind", "cieco", "schermo spento"].contains(where: value.contains) {
            return Match(command: .blindMode, requiresConfirmation: true, normalizedText: value)
        }
        if [
            "team a", "punto noi", "punto mio", "a noi", "per noi", "nostro", "nostri",
        ].contains(where: value.contains) {
            return Match(command: .pointUs, requiresConfirmation: true, normalizedText: value)
        }
        if [
            "team b", "punto loro", "punto avversario", "a loro", "per loro",
            "avversari", "avversario",
        ].contains(where: value.contains) {
            return Match(command: .pointThem, requiresConfirmation: true, normalizedText: value)
        }
        return nil
    }
}
