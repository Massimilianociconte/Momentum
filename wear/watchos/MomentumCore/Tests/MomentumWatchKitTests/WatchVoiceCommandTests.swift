@testable import MomentumWatchKit
import XCTest

final class WatchVoiceCommandTests: XCTestCase {
    func testParsesShortItalianScoringCommands() {
        XCTAssertEqual(WatchVoiceCommand.parse("Noi"), .pointUs)
        XCTAssertEqual(WatchVoiceCommand.parse("Loro"), .pointThem)
        XCTAssertEqual(WatchVoiceCommand.parse("Team A"), .pointUs)
        XCTAssertEqual(WatchVoiceCommand.parse("Team B"), .pointThem)
        XCTAssertEqual(WatchVoiceCommand.parse("punto noi"), .pointUs)
        XCTAssertEqual(WatchVoiceCommand.parse("punto mio"), .pointUs)
        XCTAssertEqual(WatchVoiceCommand.parse("punto loro"), .pointThem)
        XCTAssertEqual(WatchVoiceCommand.parse("annulla"), .undo)
        XCTAssertEqual(WatchVoiceCommand.parse("modalità cieco"), .blindMode)
        XCTAssertEqual(WatchVoiceCommand.parse("pausa"), .pause)
        XCTAssertEqual(WatchVoiceCommand.parse("riprendi"), .resume)
        XCTAssertEqual(WatchVoiceCommand.parse("termina partita"), .finish)
    }

    func testLegacyLongPhrasesRequireConfirmation() throws {
        let fuzzy = try XCTUnwrap(WatchVoiceCommand.match("segna punto noi"))
        XCTAssertEqual(fuzzy.command, .pointUs)
        XCTAssertTrue(fuzzy.requiresConfirmation)

        let exact = try XCTUnwrap(WatchVoiceCommand.match("Noi"))
        XCTAssertFalse(exact.requiresConfirmation)

        let finish = try XCTUnwrap(WatchVoiceCommand.match("Termina partita"))
        XCTAssertTrue(finish.requiresConfirmation)
    }

    func testRejectsUnrelatedSpeech() {
        XCTAssertNil(WatchVoiceCommand.parse("che bella giornata"))
    }
}
