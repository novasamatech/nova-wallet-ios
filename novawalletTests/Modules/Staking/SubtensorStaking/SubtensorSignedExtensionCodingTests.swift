import BigInt
@testable import novawallet
import SubstrateSdk
import XCTest

final class SubtensorSignedExtensionCodingTests: XCTestCase {
    private static let pinnedExtensionSlots: [Set<String>] = [
        ["CheckNonZeroSender"],
        ["CheckSpecVersion"],
        ["CheckTxVersion"],
        ["CheckGenesis"],
        ["CheckMortality"],
        ["CheckNonce"],
        ["CheckWeight"],
        ["ChargeTransactionPayment"],
        ["SudoTransactionExtension"],
        ["CheckShieldedTxValidity"],
        ["SubtensorTransactionExtension"],
        ["DrandPriority"],
        ["CheckMetadataHash"]
    ]

    private func makeExtra(
        tip: BigUInt,
        nonce: UInt32,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicExtra {
        let context = codingFactory.createRuntimeJsonContext()

        var extra = ExtrinsicExtra()
        extra[Extrinsic.TransactionExtensionId.mortality] = try Era.immortal.toScaleCompatibleJSON(
            with: context.toRawContext()
        )
        extra[Extrinsic.TransactionExtensionId.nonce] = try StringScaleMapper(
            value: nonce
        ).toScaleCompatibleJSON(with: context.toRawContext())
        extra[Extrinsic.TransactionExtensionId.txPayment] = try StringScaleMapper(
            value: tip
        ).toScaleCompatibleJSON(with: context.toRawContext())
        extra[Extrinsic.TransactionExtensionId.checkMetadataHash] = JSON.stringValue("0")

        return extra
    }

    private func encodeExtra(
        _ extra: ExtrinsicExtra,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> Data {
        let encoder = codingFactory.createEncoder()
        try encoder.append(json: .dictionaryValue(extra), type: GenericType.extrinsicExtra.name)

        return try encoder.encode()
    }

    func testSignedExtensionTupleMatchesPinnedIdentifiers() throws {
        let codingFactory = try RuntimeCodingServiceStub.createBittensorCodingFactory()

        let metadata = try XCTUnwrap(codingFactory.metadata as? PostV14RuntimeMetadataProtocol)
        let identifiers = metadata.postV14Extrinsic.signedExtensions.map(\.identifier)

        XCTAssertEqual(identifiers.count, Self.pinnedExtensionSlots.count, "\(identifiers)")

        for (identifier, slot) in zip(identifiers, Self.pinnedExtensionSlots) {
            XCTAssertTrue(slot.contains(identifier), "Unexpected extension \(identifier) in place of \(slot)")
        }
    }

    func testExtrinsicExtraRoundTripPreservesTipNonceAndEra() throws {
        let codingFactory = try RuntimeCodingServiceStub.createBittensorCodingFactory()

        let extra = try makeExtra(tip: 12345, nonce: 7, using: codingFactory)
        let encoded = try encodeExtra(extra, using: codingFactory)

        let decoder = try codingFactory.createDecoder(from: encoded)
        let decodedJson = try decoder.read(type: GenericType.extrinsicExtra.name)

        let decodedExtra = try XCTUnwrap(decodedJson.dictValue)

        XCTAssertEqual(decodedExtra.getTip(), BigUInt(12345))
        XCTAssertEqual(decodedExtra.getNonce(), 7)
        XCTAssertEqual(decodedExtra.getEra(), .immortal)
    }

    func testExtrinsicExtraEncodesTipAsCompact() throws {
        let codingFactory = try RuntimeCodingServiceStub.createBittensorCodingFactory()

        let zeroTipExtra = try makeExtra(tip: 0, nonce: 7, using: codingFactory)
        let largeTipExtra = try makeExtra(tip: 1_000_000, nonce: 7, using: codingFactory)

        let zeroTipEncoded = try encodeExtra(zeroTipExtra, using: codingFactory)
        let largeTipEncoded = try encodeExtra(largeTipExtra, using: codingFactory)

        XCTAssertEqual(largeTipEncoded.count - zeroTipEncoded.count, 3)
    }
}
