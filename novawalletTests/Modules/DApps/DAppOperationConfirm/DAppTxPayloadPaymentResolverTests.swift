import BigInt
@testable import novawallet
import SubstrateSdk
import XCTest

final class DAppTxPayloadPaymentResolverTests: XCTestCase {
    private typealias ExtensionId = Extrinsic.TransactionExtensionId
    private typealias PaymentFixture = DAppTxPayloadPaymentFixture

    // parsing the metadata takes most of the time of a test, so it is done once
    private static let assetHubRuntime = Result { try ExtrinsicGoldenRuntime.polkadotAssetHub() }

    // MARK: Fee asset

    func testPaymentWithoutAssetIsNative() throws {
        let fixture = try makeAssetHubFixture(payment: PaymentFixture.assetPayment(tip: 3))

        let payment = try resolvePayment(fixture, chain: PaymentFixture.makeAssetHubChain())

        XCTAssertNil(payment.feeAsset)
    }

    func testPaymentLeftToWalletIsNative() throws {
        let runtime = try Self.assetHubRuntime.get()
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime).removing(ExtensionId.assetTxPayment)

        let payment = try resolvePayment(fixture, chain: PaymentFixture.makeAssetHubChain())

        XCTAssertNil(payment.feeAsset)
    }

    func testAssetListedByChainBecomesFeeAsset() throws {
        let fixture = try makeAssetHubFixture(
            payment: PaymentFixture.assetPayment(tip: 0, assetLocation: PaymentFixture.usdtLocation)
        )

        let payment = try resolvePayment(fixture, chain: PaymentFixture.makeAssetHubChain())

        XCTAssertEqual(payment.feeAsset?.asset.symbol, PaymentFixture.usdtSymbol)
        XCTAssertEqual(payment.feeAsset?.asset.isUtility, false)
    }

    func testAssetTheChainDoesNotListIsRejected() throws {
        let fixture = try makeAssetHubFixture(
            payment: PaymentFixture.assetPayment(tip: 0, assetLocation: PaymentFixture.unlistedAssetLocation)
        )

        assertDecodeError(naming: ExtensionId.assetTxPayment) {
            try self.resolvePayment(fixture, chain: PaymentFixture.makeAssetHubChain())
        }
    }

    func testAssetOnChainWithoutAssetFeesIsRejected() throws {
        let fixture = try makeAssetHubFixture(
            payment: PaymentFixture.assetPayment(tip: 0, assetLocation: PaymentFixture.usdtLocation)
        )

        assertDecodeError(naming: ExtensionId.assetTxPayment) {
            try self.resolvePayment(fixture, chain: ExtrinsicGoldenRuntime.makeChain())
        }
    }

    // MARK: Tip

    func testTipOutsidePaymentExtensionsIsRejected() throws {
        let hiddenTips: [JSON] = [
            .dictionaryValue(["tip": .stringValue("7")]),
            .dictionaryValue(["tip": .unsignedIntValue(7)]),
            .dictionaryValue(["payment": .dictionaryValue(["tip": .stringValue("7")])]),
            .arrayValue([.stringValue("V1"), .dictionaryValue(["tip": .stringValue("7")])]),
            .dictionaryValue(["tip": .dictionaryValue(["amount": .stringValue("7")])])
        ]

        for explicit in hiddenTips {
            let resolution = try makeResolution(with: [("ChargeFancyPayment", explicit)])

            assertDecodeError(naming: "ChargeFancyPayment") {
                try DAppTxPayloadPaymentResolver.resolve(
                    resolution,
                    chain: PaymentFixture.makeAssetHubChain(),
                    codingFactory: Self.assetHubRuntime.get().codingFactory
                )
            }
        }
    }

    func testExtensionsWithoutTipPass() throws {
        let harmless: [JSON?] = [
            nil,
            .null,
            .stringValue("7"),
            .dictionaryValue(["tip": .stringValue("0")]),
            .dictionaryValue(["tip": .null, "priority": .stringValue("7")]),
            .arrayValue([.stringValue("Mortal"), .stringValue("5")])
        ]

        for explicit in harmless {
            let resolution = try makeResolution(with: [("AsScarcity", explicit)])

            let payment = try DAppTxPayloadPaymentResolver.resolve(
                resolution,
                chain: PaymentFixture.makeAssetHubChain(),
                codingFactory: Self.assetHubRuntime.get().codingFactory
            )

            XCTAssertNil(payment.feeAsset)
        }
    }

    func testPaymentExtensionOfUnexpectedShapeIsRejected() throws {
        let unexpected: [(String, JSON?)] = [
            (ExtensionId.txPayment, .dictionaryValue(["tip": .stringValue("7")])),
            (ExtensionId.txPayment, nil),
            (ExtensionId.assetTxPayment, .stringValue("7")),
            (ExtensionId.assetTxPayment, .dictionaryValue(["assetId": .null])),
            (ExtensionId.assetTxPayment, .dictionaryValue(["tip": .stringValue("seven"), "assetId": .null])),
            (ExtensionId.assetTxPayment, .dictionaryValue(["tip": .stringValue("7")]))
        ]

        for (identifier, explicit) in unexpected {
            let resolution = try makeResolution(with: [(identifier, explicit)])

            assertDecodeError(naming: identifier) {
                try DAppTxPayloadPaymentResolver.resolve(
                    resolution,
                    chain: PaymentFixture.makeAssetHubChain(),
                    codingFactory: Self.assetHubRuntime.get().codingFactory
                )
            }
        }
    }

    func testTotalTipSumsPaymentExtensions() throws {
        let extra: ExtrinsicExtra = [
            ExtensionId.txPayment: .stringValue("5"),
            ExtensionId.assetTxPayment: .dictionaryValue(["tip": .stringValue("3"), "assetId": .null]),
            ExtensionId.nonce: .stringValue("7")
        ]

        XCTAssertEqual(try DAppTxPayloadPaymentResolver.totalTip(in: extra), 8)
        XCTAssertEqual(try DAppTxPayloadPaymentResolver.totalTip(in: [ExtensionId.nonce: .stringValue("7")]), 0)

        assertDecodeError(naming: ExtensionId.assetTxPayment) {
            try DAppTxPayloadPaymentResolver.totalTip(in: [ExtensionId.assetTxPayment: .stringValue("3")])
        }
    }
}

private extension DAppTxPayloadPaymentResolverTests {
    func makeAssetHubFixture(payment: Data) throws -> DAppTxPayloadFixture {
        try DAppTxPayloadFixture.transfer(runtime: Self.assetHubRuntime.get())
            .replacing(ExtensionId.assetTxPayment, extra: payment)
    }

    func resolvePayment(_ fixture: DAppTxPayloadFixture, chain: ChainModel) throws -> DAppTxPayloadPayment {
        let runtime = try Self.assetHubRuntime.get()

        let resolution = try DAppTxPayloadExtensionResolver().resolve(
            payload: fixture.makePayload(),
            codingFactory: runtime.codingFactory,
            chainFacts: runtime.makeChainFacts()
        )

        return try DAppTxPayloadPaymentResolver.resolve(resolution, chain: chain, codingFactory: runtime.codingFactory)
    }

    /// A resolution whose extensions carry the given decoded explicit parts as if the dApp had supplied them.
    func makeResolution(with extensions: [(String, JSON?)]) throws -> DAppTxPayloadResolution {
        let runtime = try Self.assetHubRuntime.get()

        let verified = try DAppTxPayloadExtensionResolver().resolve(
            payload: DAppTxPayloadFixture.transfer(runtime: runtime).makePayload(),
            codingFactory: runtime.codingFactory,
            chainFacts: runtime.makeChainFacts()
        )

        return DAppTxPayloadResolution(
            extrinsicVersion: .V4,
            call: verified.call,
            extensions: extensions.map { identifier, explicit in
                DAppTxPayloadResolution.Extension(
                    identifier: identifier,
                    source: .dApp(
                        DAppTxPayloadResolution.SuppliedExtension(
                            rawExplicit: Data(),
                            rawImplicit: Data(),
                            explicit: explicit,
                            implicit: .null,
                            coder: DefaultTransactionExtensionCoder(
                                txExtensionId: identifier,
                                extensionExplicitType: KnownType.balance.name
                            )
                        )
                    )
                )
            }
        )
    }

    func assertDecodeError<T>(
        naming identifier: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ expression: () throws -> T
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            guard case let .decodeError(details) = error as? DAppCreateTransactionError else {
                XCTFail("DecodeError expected, got \(error)", file: file, line: line)
                return
            }

            XCTAssertTrue(details.contains(identifier), details, file: file, line: line)
        }
    }
}
