import BigInt
@testable import novawallet
import SubstrateSdk
import XCTest

/// Pins the `TransactionExtensionCoding` side: which coders the app registers per runtime, how they encode
/// and decode an explicit value, the JSON shape of the app's extension models and the `extra` an encoded
/// extrinsic decodes back to. Golden values were recorded on substrate-sdk-ios 4.5.2.
final class TransactionExtensionCoderCharacterizationTests: XCTestCase {
    private let extensionFactory = ExtrinsicSignedExtensionFacade().createFactory(for: KnowChainId.westend)

    // MARK: Registered coders

    func testCodersRegisteredPerRuntime() throws {
        XCTAssertEqual(try describeCoders(for: .westend()), "ChargeAssetTxPayment=pallet_asset_tx_payment.ChargeAssetTxPayment")
        XCTAssertEqual(try describeCoders(for: .bittensor()), "ChargeAssetTxPayment=pallet_asset_tx_payment.ChargeAssetTxPayment")
        XCTAssertEqual(try describeCoders(for: .polkadotAssetHub()), "ChargeAssetTxPayment=1056")
        XCTAssertEqual(try describeCoders(for: .avail()), "ChargeAssetTxPayment=pallet_asset_tx_payment.ChargeAssetTxPayment;CheckAppId=517")
    }

    func testAvailCodersAreEmptyWithoutCheckAppId() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()

        XCTAssertTrue(AvailSignedExtensionCoders.getCoders(for: runtime.metadata).isEmpty)
    }

    // MARK: Coder protocol

    func testDefaultCoderEncodesAndDecodesExplicitValue() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let extensionId = Extrinsic.TransactionExtensionId.nonce
        let explicitType = try XCTUnwrap(runtime.metadata.getSignedExtensionType(for: extensionId))
        let coder = DefaultTransactionExtensionCoder(txExtensionId: extensionId, extensionExplicitType: explicitType)

        let encoder = runtime.codingFactory.createEncoder()
        try coder.encodeIncludedInExtrinsic(from: [extensionId: .stringValue("7")], encoder: encoder)
        let encoded = try encoder.encode()

        var decoded = ExtrinsicExtra()
        let decoder = try runtime.codingFactory.createDecoder(from: encoded)
        try coder.decodeIncludedInExtrinsic(to: &decoded, decoder: decoder)

        XCTAssertEqual(encoded.toHex(includePrefix: true), "0x1c")
        XCTAssertEqual(decoded, [extensionId: .stringValue("7")])
    }

    func testDefaultCoderSkipsMissingValue() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let extensionId = Extrinsic.TransactionExtensionId.nonce
        let explicitType = try XCTUnwrap(runtime.metadata.getSignedExtensionType(for: extensionId))
        let coder = DefaultTransactionExtensionCoder(txExtensionId: extensionId, extensionExplicitType: explicitType)

        let encoder = runtime.codingFactory.createEncoder()
        try coder.encodeIncludedInExtrinsic(from: [:], encoder: encoder)

        XCTAssertTrue(try encoder.encode().isEmpty)
    }

    // MARK: Extension models as JSON

    func testAppExtensionModelsEncodeToScaleJson() throws {
        let usdt = AssetConversionPallet.AssetId(
            parents: 0,
            interior: .init(items: [.palletInstance(50), .generalIndex(1984)])
        )

        let assetConversion = try AssetConversionTxPayment(tip: BigUInt(5), assetId: usdt).toScaleCompatibleJSON()
        let assetConversionNoAsset = try AssetConversionTxPayment<JSON>().toScaleCompatibleJSON()
        let checkAppId = try AvailSignedExtension.CheckAppId(appId: 70000).toScaleCompatibleJSON()
        let chargeAsset = try TransactionExtension.ChargeAssetTxPayment(tip: BigUInt(3), assetId: 7)
            .toScaleCompatibleJSON()
        let chargeAssetDefault = try TransactionExtension.ChargeAssetTxPayment().toScaleCompatibleJSON()

        XCTAssertEqual(try ExtrinsicGolden.json(assetConversion), #"{"assetId":{"interior":["X2",[["PalletInstance","50"],["GeneralIndex","1984"]]],"parents":"0"},"tip":"5"}"#)
        XCTAssertEqual(try ExtrinsicGolden.json(assetConversionNoAsset), #"{"tip":"0"}"#)
        XCTAssertEqual(try ExtrinsicGolden.json(checkAppId), #""70000""#)
        XCTAssertEqual(try ExtrinsicGolden.json(chargeAsset), #"{"assetId":"7","tip":"3"}"#)
        XCTAssertEqual(try ExtrinsicGolden.json(chargeAssetDefault), #"{"assetId":null,"tip":"0"}"#)
    }

    func testAppExtensionModelsDecodeFromScaleJson() throws {
        let checkAppId = try JSON.stringValue("70000").map(to: AvailSignedExtension.CheckAppId.self)
        let chargeAsset = try ExtrinsicGolden.parseJSON(#"{"tip":"3","assetId":"7"}"#)
            .map(to: TransactionExtension.ChargeAssetTxPayment.self)
        let chargeAssetNoAsset = try ExtrinsicGolden.parseJSON(#"{"tip":"3","assetId":null}"#)
            .map(to: TransactionExtension.ChargeAssetTxPayment.self)
        let assetConversion = try ExtrinsicGolden.parseJSON(#"{"tip":"9","assetId":"1984"}"#)
            .map(to: AssetConversionTxPayment<JSON>.self)

        XCTAssertEqual(checkAppId.appId, 70000)
        XCTAssertEqual(chargeAsset.tip, 3)
        XCTAssertEqual(chargeAsset.assetId, 7)
        XCTAssertNil(chargeAssetNoAsset.assetId)
        XCTAssertEqual(assetConversion.tip, 9)
        XCTAssertEqual(assetConversion.assetId, .stringValue("1984"))
    }

    func testExtensionIdentifiers() {
        XCTAssertEqual(AssetConversionTxPayment<JSON>().txExtensionId, "ChargeAssetTxPayment")
        XCTAssertEqual(AvailSignedExtension.CheckAppId(appId: 0).txExtensionId, "CheckAppId")
        XCTAssertEqual(TransactionExtension.ChargeAssetTxPayment().txExtensionId, "ChargeAssetTxPayment")
        XCTAssertEqual(extensionFactory.createExtensions().map(\.txExtensionId), ["ChargeAssetTxPayment", "CheckAppId"])
    }

    // MARK: Decoding the extra of an encoded extrinsic

    func testDecodedExtraPerRuntime() throws {
        XCTAssertEqual(try decodedExtra(for: .westend()), #"{"ChargeTransactionPayment":"0","CheckGenesis":{},"CheckMortality":[1,64,5],"CheckNonZeroSender":{},"CheckNonce":"7","CheckSpecVersion":{},"CheckTxVersion":{},"CheckWeight":{}}"#)
        XCTAssertEqual(try decodedExtra(for: .bittensor(), metadataHash: ExtrinsicGolden.metadataHash), #"{"ChargeTransactionPayment":"0","CheckGenesis":{},"CheckMetadataHash":"1","CheckMortality":[1,64,5],"CheckNonZeroSender":{},"CheckNonce":"7","CheckShieldedTxValidity":{},"CheckSpecVersion":{},"CheckTxVersion":{},"CheckWeight":{},"DrandPriority":{},"SubtensorTransactionExtension":{},"SudoTransactionExtension":{}}"#)
        XCTAssertEqual(try decodedExtra(for: .polkadotAssetHub()), #"{"AuthorizeCall":{},"ChargeAssetTxPayment":{"assetId":null,"tip":"0"},"CheckGenesis":{},"CheckMetadataHash":"0","CheckMortality":[1,64,5],"CheckNonZeroSender":{},"CheckNonce":"7","CheckSpecVersion":{},"CheckTxVersion":{},"CheckWeight":{},"EthSetOrigin":{},"PrevalidateAttests":{},"StorageWeightReclaim":[]}"#)
        XCTAssertEqual(try decodedExtra(for: .avail()), #"{"ChargeTransactionPayment":"0","CheckAppId":"0","CheckGenesis":{},"CheckMortality":[1,64,5],"CheckNonZeroSender":{},"CheckNonce":"7","CheckSpecVersion":{},"CheckTxVersion":{},"CheckWeight":{}}"#)
    }

    func testDecodedExtraAccessors() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let builder = try makeProductionBuilder(for: runtime).with(tip: BigUInt(11))

        let extrinsic = try runtime.decodeExtrinsic(runtime.sign(builder).extrinsic)
        let extra = try XCTUnwrap(extrinsic.getSignedExtrinsic()).signature.extra

        XCTAssertEqual(extra.getNonce(), ExtrinsicGolden.nonce)
        XCTAssertEqual(extra.getTip(), BigUInt(11))
        XCTAssertEqual(extra.getEra(), ExtrinsicGolden.era)
    }
}

private extension TransactionExtensionCoderCharacterizationTests {
    func describeCoders(for runtime: ExtrinsicGoldenRuntime) throws -> String {
        extensionFactory.createCoders(for: runtime.metadata).map { coder in
            let explicitType = (coder as? DefaultTransactionExtensionCoder)?.extensionExplicitType ?? "custom"
            return "\(coder.txExtensionId)=\(explicitType)"
        }
        .joined(separator: ";")
    }

    func makeProductionBuilder(for runtime: ExtrinsicGoldenRuntime) throws -> ExtrinsicBuilderProtocol {
        var builder = try runtime.makeBuilder()

        for customExtension in extensionFactory.createExtensions() {
            builder = builder.adding(transactionExtension: customExtension)
        }

        return try builder.adding(call: ExtrinsicGolden.transferCall())
    }

    func decodedExtra(for runtime: ExtrinsicGoldenRuntime, metadataHash: Data? = nil) throws -> String {
        var builder = try makeProductionBuilder(for: runtime)

        if let metadataHash {
            builder = builder.with(metadataHash: metadataHash)
        }

        let extrinsic = try runtime.decodeExtrinsic(runtime.sign(builder).extrinsic)
        let signed = try XCTUnwrap(extrinsic.getSignedExtrinsic())

        return try ExtrinsicGolden.json(signed.signature.extra)
    }
}
