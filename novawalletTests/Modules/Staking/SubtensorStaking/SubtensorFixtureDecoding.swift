import Foundation
@testable import novawallet
import SubstrateSdk
import XCTest

enum SubtensorFixtureDecoding {
    static func decodeRuntimeApiResult<T: Decodable>(
        from hex: String,
        path: StateCallPath,
        codingFactory: RuntimeCoderFactoryProtocol? = nil
    ) throws -> T {
        let factory = try codingFactory ?? RuntimeCodingServiceStub.createBittensorCodingFactory()

        let runtimeApi = try factory.metadata.getRuntimeApiMethodOrError(
            for: path.module,
            methodName: path.method
        )

        let decoder = StateCallResultFromTypeNameDecoder<T>(typeName: runtimeApi.method.output.asTypeId())

        return try decoder.decode(data: try Data(hexString: hex), using: factory)
    }

    static func decodeEvents(
        _ eventsHex: [String],
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> [Event] {
        let entry = try XCTUnwrap(codingFactory.metadata.getStorageMetadata(for: SystemPallet.eventsPath))

        let recordsHex = littleEndianHex(UInt8(eventsHex.count << 2)) +
            eventsHex.map { "00" + "00000000" + $0 + "00" }.joined()
        let decoder = try codingFactory.createDecoder(from: Data(hexString: recordsHex))
        let json = try decoder.read(type: entry.type.typeName)

        return try json.map(
            to: [EventRecord].self,
            with: codingFactory.createRuntimeJsonContext().toRawContext()
        ).map(\.event)
    }

    static func littleEndianHex<T: FixedWidthInteger>(_ value: T) -> String {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }.toHex()
    }

    static func stakeAddedEvent(
        coldkey: AccountId,
        hotkey: AccountId,
        netuid: UInt16,
        tao: UInt64,
        alpha: UInt64,
        poolFee: UInt64
    ) -> String {
        "0702" + coldkey.toHex() + hotkey.toHex() + littleEndianHex(tao) + littleEndianHex(alpha) +
            littleEndianHex(netuid) + littleEndianHex(poolFee)
    }

    static func stakeRemovedEvent(
        coldkey: AccountId,
        hotkey: AccountId,
        netuid: UInt16,
        tao: UInt64,
        alpha: UInt64,
        poolFee: UInt64
    ) -> String {
        "0703" + coldkey.toHex() + hotkey.toHex() + littleEndianHex(tao) + littleEndianHex(alpha) +
            littleEndianHex(netuid) + littleEndianHex(poolFee)
    }

    static func alphaFeePaidEvent(coldkey: AccountId, netuid: UInt16, alphaFee: UInt64, taoAmount: UInt64) -> String {
        "0780" + coldkey.toHex() + littleEndianHex(netuid) + littleEndianHex(alphaFee) + littleEndianHex(taoAmount)
    }

    static func transactionFeePaidEvent(who: AccountId, actualFee: UInt64) -> String {
        "0600" + who.toHex() + littleEndianHex(actualFee) + littleEndianHex(UInt64(0))
    }

    static func transferEvent(from sender: AccountId, to receiver: AccountId, amount: UInt64) -> String {
        "0502" + sender.toHex() + receiver.toHex() + littleEndianHex(amount)
    }

    static func batchInterruptedEvent(itemIndex: UInt32, palletIndex: UInt8, errorIndex: UInt8) -> String {
        "0b00" + littleEndianHex(itemIndex) + "03" + littleEndianHex(palletIndex) + littleEndianHex(errorIndex) + "000000"
    }
}
