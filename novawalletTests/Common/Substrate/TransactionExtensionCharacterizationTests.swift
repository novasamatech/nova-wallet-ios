import BigInt
@testable import novawallet
import SubstrateSdk
import XCTest

/// Pins the explicit (inside the extrinsic) and implicit (inside the signed payload) bytes of every
/// transaction extension the app defines or configures, per runtime fixture.
/// Golden values were recorded on substrate-sdk-ios 4.5.2.
final class TransactionExtensionCharacterizationTests: XCTestCase {
    private let extensionFactory = ExtrinsicSignedExtensionFacade().createFactory(for: KnowChainId.westend)

    // MARK: Westend: era, nonce, tip

    func testWestendMortalEraExplicitAndImplicit() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()

        let params = try runtime.signatureParams(of: makeProductionBuilder(for: runtime))

        XCTAssertEqual(params.includedInExtrinsicExtra.toHex(includePrefix: true), "0x55001c00")
        XCTAssertEqual(params.includedInSignatureExtra.toHex(includePrefix: true), "0x2c2400000b000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
    }

    func testWestendImmortalEraExplicitAndImplicit() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()

        let params = try runtime.signatureParams(of: makeProductionBuilder(for: runtime, era: .immortal))

        XCTAssertEqual(params.includedInExtrinsicExtra.toHex(includePrefix: true), "0x001c00")
        XCTAssertEqual(params.includedInSignatureExtra.toHex(includePrefix: true), "0x2c2400000b000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
    }

    func testWestendTipExplicit() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let builder = try makeProductionBuilder(for: runtime).with(tip: BigUInt(1_000_000))

        let params = try runtime.signatureParams(of: builder)

        XCTAssertEqual(params.includedInExtrinsicExtra.toHex(includePrefix: true), "0x55001c02093d00")
    }

    func testWestendMetadataHashIsIgnoredWhenRuntimeHasNoExtension() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let plain = try makeProductionBuilder(for: runtime)
        let withHash = try makeProductionBuilder(for: runtime).with(metadataHash: ExtrinsicGolden.metadataHash)

        XCTAssertEqual(try runtime.signaturePayload(of: withHash), try runtime.signaturePayload(of: plain))
    }

    // MARK: Bittensor: CheckMetadataHash and the Subtensor specific extensions

    func testBittensorExtensionsWithMetadataHashDisabled() throws {
        let runtime = try ExtrinsicGoldenRuntime.bittensor()

        let params = try runtime.signatureParams(of: makeProductionBuilder(for: runtime))

        XCTAssertEqual(params.includedInExtrinsicExtra.toHex(includePrefix: true), "0x55001c0000")
        XCTAssertEqual(params.includedInSignatureExtra.toHex(includePrefix: true), "0xd601000001000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00")
    }

    func testBittensorExtensionsWithMetadataHashEnabled() throws {
        let runtime = try ExtrinsicGoldenRuntime.bittensor()
        let builder = try makeProductionBuilder(for: runtime).with(metadataHash: ExtrinsicGolden.metadataHash)

        let params = try runtime.signatureParams(of: builder)

        XCTAssertEqual(params.includedInExtrinsicExtra.toHex(includePrefix: true), "0x55001c0001")
        XCTAssertEqual(params.includedInSignatureExtra.toHex(includePrefix: true), "0xd601000001000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb01cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc")
    }

    func testBittensorSignedExtrinsicAndSignedPayload() throws {
        let runtime = try ExtrinsicGoldenRuntime.bittensor()
        let builder = try makeProductionBuilder(for: runtime).with(metadataHash: ExtrinsicGolden.metadataHash)

        let signed = try runtime.sign(builder)

        XCTAssertEqual(signed.signedPayload, "0x0503002222222222222222222222222222222222222222222222222222222222222222070010a5d4e855001c0001d601000001000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb01cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc")
        XCTAssertEqual(signed.extrinsic, "0x45028400111111111111111111111111111111111111111111111111111111111111111101abababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababab55001c00010503002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8")
    }

    func testBittensorShieldedClosureForcesZeroTip() throws {
        let runtime = try ExtrinsicGoldenRuntime.bittensor()
        let tipped = try makeProductionBuilder(for: runtime, addsCall: false).with(tip: BigUInt(77))

        let closure = SubtensorShieldExtrinsicOperationFactory.shieldedClosure { builder in
            try builder.adding(call: ExtrinsicGolden.transferCall())
        }
        let shielded = try closure(tipped)

        XCTAssertEqual(
            try runtime.signaturePayload(of: shielded),
            try runtime.signaturePayload(of: makeProductionBuilder(for: runtime))
        )
    }

    // MARK: Polkadot Asset Hub: ChargeAssetTxPayment

    func testAssetHubDefaultChargeAssetTxPayment() throws {
        let runtime = try ExtrinsicGoldenRuntime.polkadotAssetHub()

        let params = try runtime.signatureParams(of: makeProductionBuilder(for: runtime))

        XCTAssertEqual(params.includedInExtrinsicExtra.toHex(includePrefix: true), "0x55001c000000")
        XCTAssertEqual(params.includedInSignatureExtra.toHex(includePrefix: true), "0x08981e000f000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00")
    }

    func testAssetHubDefaultTipGoesIntoChargeAssetTxPaymentOnlyWhenSetOnExtension() throws {
        let runtime = try ExtrinsicGoldenRuntime.polkadotAssetHub()
        let builderTip = try makeProductionBuilder(for: runtime).with(tip: BigUInt(9))
        let extensionTip = try makeProductionBuilder(for: runtime)
            .adding(transactionExtension: TransactionExtension.ChargeAssetTxPayment(tip: BigUInt(9)))

        // `with(tip:)` configures ChargeTransactionPayment, which Asset Hub does not have
        XCTAssertEqual(
            try runtime.signaturePayload(of: builderTip),
            try runtime.signaturePayload(of: makeProductionBuilder(for: runtime))
        )
        XCTAssertEqual(try runtime.signatureParams(of: extensionTip).includedInExtrinsicExtra.toHex(includePrefix: true), "0x55001c240000")
    }

    func testAssetHubAssetConversionTxPaymentInUsdt() throws {
        let runtime = try ExtrinsicGoldenRuntime.polkadotAssetHub()
        var builder = try makeProductionBuilder(for: runtime)

        for feeExtension in extensionFactory.createExtensions(payingFeeIn: Self.usdtAssetId) {
            builder = builder.adding(transactionExtension: feeExtension)
        }

        let params = try runtime.signatureParams(of: builder)
        let signed = try runtime.sign(builder)

        XCTAssertEqual(params.includedInExtrinsicExtra.toHex(includePrefix: true), "0x55001c00010002043205011f00")
        XCTAssertEqual(params.includedInSignatureExtra.toHex(includePrefix: true), "0x08981e000f000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00")
        XCTAssertEqual(signed.signedPayload, "0x0a03002222222222222222222222222222222222222222222222222222222222222222070010a5d4e855001c00010002043205011f0008981e000f000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00")
        XCTAssertEqual(signed.extrinsic, "0x65028400111111111111111111111111111111111111111111111111111111111111111101abababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababab55001c00010002043205011f000a03002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8")
    }

    func testAssetHubAssetConversionTxPaymentWithTipAndRelayNativeAsset() throws {
        let runtime = try ExtrinsicGoldenRuntime.polkadotAssetHub()
        let relayNative = AssetConversionPallet.AssetId(parents: 1, interior: .init(items: []))
        let builder = try makeProductionBuilder(for: runtime)
            .adding(transactionExtension: AssetConversionTxPayment(tip: BigUInt(500), assetId: relayNative))

        let params = try runtime.signatureParams(of: builder)

        XCTAssertEqual(params.includedInExtrinsicExtra.toHex(includePrefix: true), "0x55001cd10701010000")
    }

    func testAssetHubMetadataHashEnabled() throws {
        let runtime = try ExtrinsicGoldenRuntime.polkadotAssetHub()
        let builder = try makeProductionBuilder(for: runtime).with(metadataHash: ExtrinsicGolden.metadataHash)

        let params = try runtime.signatureParams(of: builder)

        XCTAssertEqual(params.includedInExtrinsicExtra.toHex(includePrefix: true), "0x55001c000001")
        XCTAssertEqual(params.includedInSignatureExtra.toHex(includePrefix: true), "0x08981e000f000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb01cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc")
    }

    // MARK: Avail: CheckAppId

    func testAvailDefaultCheckAppId() throws {
        let runtime = try ExtrinsicGoldenRuntime.avail()
        let builder = try makeProductionBuilder(for: runtime)

        let params = try runtime.signatureParams(of: builder)
        let signed = try runtime.sign(builder)

        XCTAssertEqual(params.includedInExtrinsicExtra.toHex(includePrefix: true), "0x55001c0000")
        XCTAssertEqual(params.includedInSignatureExtra.toHex(includePrefix: true), "0x3800000001000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
        XCTAssertEqual(signed.signedPayload, "0x0603002222222222222222222222222222222222222222222222222222222222222222070010a5d4e855001c00003800000001000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
        XCTAssertEqual(signed.extrinsic, "0x45028400111111111111111111111111111111111111111111111111111111111111111101abababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababab55001c00000603002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8")
    }

    func testAvailCustomCheckAppId() throws {
        let runtime = try ExtrinsicGoldenRuntime.avail()
        let builder = try makeProductionBuilder(for: runtime)
            .adding(transactionExtension: AvailSignedExtension.CheckAppId(appId: 70000))

        let params = try runtime.signatureParams(of: builder)

        XCTAssertEqual(params.includedInExtrinsicExtra.toHex(includePrefix: true), "0x55001c00c2450400")
    }
}

private extension TransactionExtensionCharacterizationTests {
    static let usdtAssetId = AssetConversionPallet.AssetId(
        parents: 0,
        interior: .init(items: [.palletInstance(50), .generalIndex(1984)])
    )

    /// Mirrors `ExtrinsicOperationFactory`: the default extension set of the app is installed on every builder.
    func makeProductionBuilder(
        for runtime: ExtrinsicGoldenRuntime,
        era: Era = ExtrinsicGolden.era,
        addsCall: Bool = true
    ) throws -> ExtrinsicBuilderProtocol {
        var builder = try runtime.makeBuilder(era: era)

        for customExtension in extensionFactory.createExtensions() {
            builder = builder.adding(transactionExtension: customExtension)
        }

        return addsCall ? try builder.adding(call: ExtrinsicGolden.transferCall()) : builder
    }
}
