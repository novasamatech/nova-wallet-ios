import BigInt
@testable import novawallet
import SubstrateSdk
import XCTest

final class SubtensorExecutedOutcomeParserTests: XCTestCase {
    private let coldkeyHex = String(repeating: "11", count: 32)
    private let hotkeyHex = String(repeating: "22", count: 32)
    private let recordPrefixHex = "04" + "00" + "00000000"
    private let emptyTopicsHex = "00"

    private func decodeEvents(from hex: String) throws -> ([Event], RuntimeCoderFactoryProtocol) {
        let codingFactory = try RuntimeCodingServiceStub.createBittensorCodingFactory()

        let entry = try XCTUnwrap(
            codingFactory.metadata.getStorageMetadata(for: SystemPallet.eventsPath)
        )

        let decoder = try codingFactory.createDecoder(from: Data(hexString: hex))
        let json = try decoder.read(type: entry.type.typeName)

        let context = codingFactory.createRuntimeJsonContext()
        let records = try json.map(to: [EventRecord].self, with: context.toRawContext())

        return (records.map(\.event), codingFactory)
    }

    private func decodeSingleEvent(from hex: String) throws -> (Event, RuntimeCoderFactoryProtocol) {
        let (events, codingFactory) = try decodeEvents(from: hex)

        return try (XCTUnwrap(events.first), codingFactory)
    }

    func testStakeAddedEventParsesToStakedOutcomeWithTaoAmount() throws {
        let eventHex = "0702" + coldkeyHex + hotkeyHex +
            "00ca9a3b00000000" + "00286bee00000000" + "0000" + "1027000000000000"

        let (event, codingFactory) = try decodeSingleEvent(
            from: recordPrefixHex + eventHex + emptyTopicsHex
        )

        let outcome = SubtensorExecutedOutcomeParser.parseOutcome(
            from: [event],
            codingFactory: codingFactory
        )

        XCTAssertEqual(outcome, .staked(tao: 1_000_000_000))
    }

    func testStakeRemovedEventParsesToUnstakedOutcomeWithTaoAmount() throws {
        let eventHex = "0703" + coldkeyHex + hotkeyHex +
            "00ca9a3b00000000" + "00286bee00000000" + "0100" + "0000000000000000"

        let (event, codingFactory) = try decodeSingleEvent(
            from: recordPrefixHex + eventHex + emptyTopicsHex
        )

        let outcome = SubtensorExecutedOutcomeParser.parseOutcome(
            from: [event],
            codingFactory: codingFactory
        )

        XCTAssertEqual(outcome, .unstaked(tao: 1_000_000_000))
    }

    func testFeeInAlphaStakeRemovedPrecedingDispatchEventReportsDispatchAmount() throws {
        let feeEventHex = "0703" + coldkeyHex + hotkeyHex +
            "404b4c0000000000" + "8096980000000000" + "0100" + "0000000000000000"
        let dispatchEventHex = "0703" + coldkeyHex + hotkeyHex +
            "00ca9a3b00000000" + "00286bee00000000" + "0100" + "0000000000000000"

        let recordsHex = "08" +
            "00" + "00000000" + feeEventHex + emptyTopicsHex +
            "00" + "00000000" + dispatchEventHex + emptyTopicsHex

        let (events, codingFactory) = try decodeEvents(from: recordsHex)

        let outcome = SubtensorExecutedOutcomeParser.parseOutcome(
            from: events,
            codingFactory: codingFactory
        )

        XCTAssertEqual(outcome, .unstaked(tao: 1_000_000_000))
    }

    func testRootClaimedEventParsesToClaimedOutcome() throws {
        let eventHex = "0773" + coldkeyHex + "40420f0000000000"

        let (event, codingFactory) = try decodeSingleEvent(
            from: recordPrefixHex + eventHex + emptyTopicsHex
        )

        let outcome = SubtensorExecutedOutcomeParser.parseOutcome(
            from: [event],
            codingFactory: codingFactory
        )

        XCTAssertEqual(outcome, .claimed(tao: 1_000_000))
    }

    func testRootClaimedZeroTaoParsesToClaimedZero() throws {
        let eventHex = "0773" + coldkeyHex + "0000000000000000"

        let (event, codingFactory) = try decodeSingleEvent(
            from: recordPrefixHex + eventHex + emptyTopicsHex
        )

        let outcome = SubtensorExecutedOutcomeParser.parseOutcome(
            from: [event],
            codingFactory: codingFactory
        )

        XCTAssertEqual(outcome, .claimed(tao: 0))
    }

    func testNoEventsParsesToNilOutcome() throws {
        let codingFactory = try RuntimeCodingServiceStub.createBittensorCodingFactory()

        let outcome = SubtensorExecutedOutcomeParser.parseOutcome(
            from: [],
            codingFactory: codingFactory
        )

        XCTAssertNil(outcome)
    }
}
