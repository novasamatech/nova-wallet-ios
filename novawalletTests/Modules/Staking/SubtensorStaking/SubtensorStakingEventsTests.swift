import BigInt
@testable import novawallet
import SubstrateSdk
import XCTest

final class SubtensorStakingEventsTests: XCTestCase {
    private let coldkeyHex = String(repeating: "11", count: 32)
    private let hotkeyHex = String(repeating: "22", count: 32)
    private let recordPrefixHex = "04" + "00" + "00000000"
    private let emptyTopicsHex = "00"

    private func decodeSingleEvent(from hex: String) throws -> (Event, RuntimeCoderFactoryProtocol) {
        let codingFactory = try RuntimeCodingServiceStub.createBittensorCodingFactory()

        let entry = try XCTUnwrap(
            codingFactory.metadata.getStorageMetadata(for: SystemPallet.eventsPath)
        )

        let decoder = try codingFactory.createDecoder(from: Data(hexString: hex))
        let json = try decoder.read(type: entry.type.typeName)

        let context = codingFactory.createRuntimeJsonContext()
        let records = try json.map(to: [EventRecord].self, with: context.toRawContext())

        let record = try XCTUnwrap(records.first)

        return (record.event, codingFactory)
    }

    func testStakeAddedEventDecodesPinnedFieldOrder() throws {
        let eventHex = "0702" + coldkeyHex + hotkeyHex +
            "00ca9a3b00000000" + "00286bee00000000" + "0000" + "1027000000000000"

        let (event, codingFactory) = try decodeSingleEvent(
            from: recordPrefixHex + eventHex + emptyTopicsHex
        )

        XCTAssertTrue(
            codingFactory.metadata.eventMatches(event, path: SubtensorStakingPallet.stakeAddedEventPath)
        )

        let context = codingFactory.createRuntimeJsonContext()
        let stakeAdded = try event.params.map(
            to: SubtensorStakingPallet.StakeAddedEvent.self,
            with: context.toRawContext()
        )

        XCTAssertEqual(stakeAdded.coldkey, Data(repeating: 0x11, count: 32))
        XCTAssertEqual(stakeAdded.hotkey, Data(repeating: 0x22, count: 32))
        XCTAssertEqual(stakeAdded.tao, BigUInt(1_000_000_000))
        XCTAssertEqual(stakeAdded.alpha, BigUInt(4_000_000_000))
        XCTAssertEqual(stakeAdded.netuid, 0)
        XCTAssertEqual(stakeAdded.fee, BigUInt(10000))
    }

    func testStakeRemovedEventDecodesPinnedFieldOrder() throws {
        let eventHex = "0703" + coldkeyHex + hotkeyHex +
            "00ca9a3b00000000" + "00286bee00000000" + "0100" + "0000000000000000"

        let (event, codingFactory) = try decodeSingleEvent(
            from: recordPrefixHex + eventHex + emptyTopicsHex
        )

        XCTAssertTrue(
            codingFactory.metadata.eventMatches(event, path: SubtensorStakingPallet.stakeRemovedEventPath)
        )

        let context = codingFactory.createRuntimeJsonContext()
        let stakeRemoved = try event.params.map(
            to: SubtensorStakingPallet.StakeRemovedEvent.self,
            with: context.toRawContext()
        )

        XCTAssertEqual(stakeRemoved.coldkey, Data(repeating: 0x11, count: 32))
        XCTAssertEqual(stakeRemoved.hotkey, Data(repeating: 0x22, count: 32))
        XCTAssertEqual(stakeRemoved.tao, BigUInt(1_000_000_000))
        XCTAssertEqual(stakeRemoved.alpha, BigUInt(4_000_000_000))
        XCTAssertEqual(stakeRemoved.netuid, 1)
        XCTAssertEqual(stakeRemoved.fee, BigUInt(0))
    }

    func testRootClaimedEventDecodesNamedFields() throws {
        let eventHex = "0773" + coldkeyHex + "40420f0000000000"

        let (event, codingFactory) = try decodeSingleEvent(
            from: recordPrefixHex + eventHex + emptyTopicsHex
        )

        XCTAssertTrue(
            codingFactory.metadata.eventMatches(event, path: SubtensorStakingPallet.rootClaimedEventPath)
        )

        let context = codingFactory.createRuntimeJsonContext()
        let rootClaimed = try event.params.map(
            to: SubtensorStakingPallet.RootClaimedEvent.self,
            with: context.toRawContext()
        )

        XCTAssertEqual(rootClaimed.coldkey, Data(repeating: 0x11, count: 32))
        XCTAssertEqual(rootClaimed.tao, BigUInt(1_000_000))
    }

    func testRootClaimedEventDecodesZeroTao() throws {
        let eventHex = "0773" + coldkeyHex + "0000000000000000"

        let (event, codingFactory) = try decodeSingleEvent(
            from: recordPrefixHex + eventHex + emptyTopicsHex
        )

        let context = codingFactory.createRuntimeJsonContext()
        let rootClaimed = try event.params.map(
            to: SubtensorStakingPallet.RootClaimedEvent.self,
            with: context.toRawContext()
        )

        XCTAssertEqual(rootClaimed.tao, BigUInt(0))
    }
}
