import BigInt
@testable import novawallet
import SubstrateSdk
import XCTest

final class DAppTxPayloadExtensionResolverTests: XCTestCase {
    private typealias ExtensionId = Extrinsic.TransactionExtensionId

    private let resolver = DAppTxPayloadExtensionResolver()

    // MARK: Version

    func testCompletePayloadResolvesToLegacyExtrinsicBuiltFromDAppExtensions() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)

        let resolution = try resolve(fixture, runtime: runtime)

        XCTAssertEqual(resolution.extrinsicVersion, .V4)
        XCTAssertEqual(resolution.extensions.map(\.identifier), runtime.metadata.getSignedExtensions())
        XCTAssertTrue(resolution.extensions.allSatisfy { $0.source.isSuppliedByDApp })
        XCTAssertEqual(resolution.call.moduleName, "Balances")
        XCTAssertEqual(resolution.call.callName, "transfer_keep_alive")

        let nonce = try XCTUnwrap(resolution.supplied(for: ExtensionId.nonce))

        XCTAssertEqual(nonce.rawExplicit, Data([0x1C]))
        XCTAssertEqual(nonce.explicit, .stringValue("7"))
    }

    func testMissingExtensionVersionMeansLegacyExtrinsic() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        var fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)
        fixture.txExtVersion = nil

        XCTAssertEqual(try resolve(fixture, runtime: runtime).extrinsicVersion, .V4)
    }

    func testNonZeroExtensionVersionIsUnsupportedByMetadataBeforeV16() throws {
        for runtime in [try ExtrinsicGoldenRuntime.westend(), try ExtrinsicGoldenRuntime.bittensor()] {
            var fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)
            fixture.txExtVersion = 1

            assertFailure(fixture, runtime: runtime, name: "UnsupportedTxExtensionVersion")
        }
    }

    func testRealMetadataV16KeepsLegacyExtrinsicAndHasNoGeneralTransactionPipeline() throws {
        let runtime = try ExtrinsicGoldenRuntime.westendV16()
        var fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)

        XCTAssertEqual(runtime.metadata.getSupportedFormatVersions(), [4, 5])
        XCTAssertEqual(runtime.metadata.getSupportedExtensionVersions(), [0])
        XCTAssertFalse(runtime.metadata.getSignedExtensions().contains(ExtensionId.verifySignature))

        XCTAssertEqual(try resolve(fixture, runtime: runtime).extrinsicVersion, .V4)

        fixture.txExtVersion = 1

        assertFailure(fixture, runtime: runtime, name: "UnsupportedTxExtensionVersion")
    }

    func testBaseExtensionVersionPrefersLegacyFormatWhenRuntimeHasBoth() throws {
        let runtime = try ExtrinsicGoldenRuntime.westendV16(customization: .init(formats: [4, 5]))
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)

        let resolution = try resolve(fixture, runtime: runtime)

        XCTAssertEqual(resolution.extrinsicVersion, .V4)
        XCTAssertEqual(resolution.extensions.first?.identifier, ExtensionId.verifySignature)
        XCTAssertTrue(resolution.extensions.first?.source.isSignature == true)
    }

    func testBaseExtensionVersionBecomesGeneralTransactionWithoutLegacyFormat() throws {
        let runtime = try ExtrinsicGoldenRuntime.westendV16(customization: .init(formats: [5]))
        var fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)

        XCTAssertEqual(try resolve(fixture, runtime: runtime).extrinsicVersion, .V5(extensionVersion: 0))

        fixture.txExtVersion = nil

        XCTAssertEqual(try resolve(fixture, runtime: runtime).extrinsicVersion, .V5(extensionVersion: 0))
    }

    func testNonZeroExtensionVersionSelectsItsOwnPipeline() throws {
        let allIds = try ExtrinsicGoldenRuntime.westendV16ExtensionIds()
        let secondSet = allIds.filter { $0 != ExtensionId.txPayment && $0 != ExtensionId.checkMetadataHash }

        let runtime = try ExtrinsicGoldenRuntime.westendV16(
            customization: .init(formats: [4, 5], extensionSets: [0: allIds, 1: secondSet])
        )

        // the dApp sends the extensions of every version, as PAPI does
        var fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)
        fixture.txExtVersion = 1

        let resolution = try resolve(fixture, runtime: runtime)

        XCTAssertEqual(resolution.extrinsicVersion, .V5(extensionVersion: 1))
        XCTAssertEqual(resolution.extensions.map(\.identifier), secondSet)
        XCTAssertNil(resolution.supplied(for: ExtensionId.txPayment))
    }

    func testGeneralTransactionRequirements() throws {
        let allIds = try ExtrinsicGoldenRuntime.westendV16ExtensionIds()
        let withoutSignature = allIds.filter { $0 != ExtensionId.verifySignature }

        let legacyOnly = try ExtrinsicGoldenRuntime.westendV16(
            customization: .init(formats: [4], extensionSets: [0: allIds, 1: allIds])
        )

        let runtime = try ExtrinsicGoldenRuntime.westendV16(
            customization: .init(formats: [4, 5], extensionSets: [0: allIds, 1: allIds, 2: withoutSignature])
        )

        let generalOnlyWithoutSignature = try ExtrinsicGoldenRuntime.westendV16(
            customization: .init(formats: [5], extensionSets: [0: withoutSignature])
        )

        var fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)
        fixture.txExtVersion = 1

        XCTAssertEqual(try resolve(fixture, runtime: runtime).extrinsicVersion, .V5(extensionVersion: 1))
        assertFailure(fixture, runtime: legacyOnly, name: "UnsupportedTxExtensionVersion")

        for unsupportedVersion: UInt in [2, 3, 256] {
            fixture.txExtVersion = unsupportedVersion

            assertFailure(fixture, runtime: runtime, name: "UnsupportedTxExtensionVersion")
        }

        fixture.txExtVersion = 0

        assertFailure(fixture, runtime: generalOnlyWithoutSignature, name: "UnsupportedTxExtensionVersion")
    }

    // MARK: Supplied extensions

    func testTrailingBytesAreRejected() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)
        let genesisHash = try Data(hexString: ExtrinsicGolden.genesisHash)

        let withExplicitTail = fixture.replacing(ExtensionId.nonce, extra: Data([0x1C, 0x00]))
        let withImplicitTail = fixture.replacing(ExtensionId.nonce, extra: Data([0x1C]), additionalSigned: Data([0x00]))
        let withZeroSizedTail = fixture.replacing("CheckWeight", extra: Data([0x00]))

        let withGenesisTail = fixture.replacing(
            ExtensionId.genesis,
            extra: Data(),
            additionalSigned: genesisHash + Data([0x00])
        )

        var withCallTail = fixture
        withCallTail.callData += "00"

        for invalidFixture in [withExplicitTail, withImplicitTail, withZeroSizedTail, withGenesisTail, withCallTail] {
            assertFailure(invalidFixture, runtime: runtime, name: "DecodeError")
        }
    }

    func testNonCanonicalEncodingIsRejected() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)

        // 7 as a two byte compact integer: decodable, but the canonical form takes one byte
        let nonCanonicalNonce = fixture.replacing(ExtensionId.nonce, extra: Data([0x1D, 0x00]))

        assertFailure(nonCanonicalNonce, runtime: runtime, name: "DecodeError")
    }

    func testValuesDifferentFromWalletOnesAreRejected() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()

        var anotherGenesis = DAppTxPayloadFixture.Values()
        anotherGenesis.genesisHash = "0x" + String(repeating: "ab", count: 32)

        var anotherSpecVersion = DAppTxPayloadFixture.Values()
        anotherSpecVersion.specVersion = runtime.codingFactory.specVersion + 1

        var anotherTransactionVersion = DAppTxPayloadFixture.Values()
        anotherTransactionVersion.transactionVersion = runtime.codingFactory.txVersion + 1

        for values in [anotherGenesis, anotherSpecVersion, anotherTransactionVersion] {
            let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime, values: values)

            assertFailure(fixture, runtime: runtime, name: "DecodeError")
        }
    }

    func testPayloadOfAnotherChainIsRejected() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        var fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)
        fixture.genesisHash = "0x" + String(repeating: "ab", count: 32)

        assertFailure(fixture, runtime: runtime, name: "DecodeError")
    }

    func testMetadataHashMustBeTheWalletOne() throws {
        let runtime = try ExtrinsicGoldenRuntime.bittensor()
        let walletHash = ExtrinsicGolden.metadataHash
        let extensionId = ExtensionId.checkMetadataHash

        var values = DAppTxPayloadFixture.Values()
        values.metadataHash = walletHash

        let enabled = try DAppTxPayloadFixture.transfer(runtime: runtime, values: values)
        let disabled = try DAppTxPayloadFixture.transfer(runtime: runtime)

        XCTAssertTrue(try resolve(enabled, runtime: runtime, metadataHash: walletHash).supplied(for: extensionId) != nil)
        XCTAssertTrue(try resolve(disabled, runtime: runtime, metadataHash: walletHash).supplied(for: extensionId) != nil)
        XCTAssertTrue(try resolve(disabled, runtime: runtime, metadataHash: nil).supplied(for: extensionId) != nil)

        // the wallet has another hash or can't compute one
        assertFailure(enabled, runtime: runtime, metadataHash: Data(repeating: 0xEE, count: 32), name: "DecodeError")
        assertFailure(enabled, runtime: runtime, metadataHash: nil, name: "DecodeError")

        let disabledWithHash = disabled.replacing(
            extensionId,
            extra: Data([0]),
            additionalSigned: Data([1]) + walletHash
        )

        let unknownMode = disabled.replacing(extensionId, extra: Data([2]), additionalSigned: Data([0]))

        assertFailure(disabledWithHash, runtime: runtime, metadataHash: walletHash, name: "DecodeError")
        assertFailure(unknownMode, runtime: runtime, metadataHash: walletHash, name: "DecodeError")
    }

    /// `createSdkCoders()` repeats a list substrate-sdk-ios keeps internal. Whatever the wallet decodes from
    /// the dApp's bytes must be what `ExtrinsicExtraNode` reads from the same bytes in an extrinsic, so a list
    /// that no longer follows the SDK shows up here and not as refused payloads.
    func testSuppliedExtensionsAreDecodedTheWayExtraNodeDecodesThem() throws {
        var westendValues = DAppTxPayloadFixture.Values()
        westendValues.tip = 5

        var assetHubValues = westendValues
        assetHubValues.metadataHash = ExtrinsicGolden.metadataHash

        let cases: [(runtime: ExtrinsicGoldenRuntime, values: DAppTxPayloadFixture.Values)] = [
            (try ExtrinsicGoldenRuntime.westend(), westendValues),
            (try ExtrinsicGoldenRuntime.polkadotAssetHub(), assetHubValues)
        ]

        for (runtime, values) in cases {
            // given

            let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime, values: values)
            let resolution = try resolve(fixture, runtime: runtime, metadataHash: values.metadataHash)

            let supplied = try resolution.extensions.map { try XCTUnwrap(resolution.supplied(for: $0.identifier)) }
            let extraBytes = supplied.reduce(Data()) { $0 + $1.rawExplicit }

            let extraNode = try XCTUnwrap(
                runtime.codingFactory.getTypeNode(for: GenericType.extrinsicExtra.name) as? ExtrinsicExtraNode
            )

            // when

            let decoder = try runtime.codingFactory.createDecoder(from: extraBytes)
            let nodeExtra = try extraNode.decode(extensionVersion: 0, decoder: decoder)

            // then

            XCTAssertEqual(decoder.remained, 0)

            for (resolved, suppliedExtension) in zip(resolution.extensions, supplied) {
                XCTAssertEqual(suppliedExtension.explicit, nodeExtra[resolved.identifier], resolved.identifier)
            }

            let hasTransactionPayment = runtime.metadata.getSignedExtensions().contains(ExtensionId.txPayment)

            XCTAssertEqual(nodeExtra.getTip(), hasTransactionPayment ? BigUInt(5) : nil)
        }
    }

    func testInvalidHexIsReported() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)

        var invalidExplicit = fixture.removing(ExtensionId.nonce)
        invalidExplicit.extensions.append(.init(id: ExtensionId.nonce, extra: "0xzz", additionalSigned: "0x"))

        var invalidImplicit = fixture.removing(ExtensionId.nonce)
        invalidImplicit.extensions.append(.init(id: ExtensionId.nonce, extra: "0x1c", additionalSigned: "0x1"))

        var invalidCall = fixture
        invalidCall.callData = "0x04gg"

        var invalidGenesis = fixture
        invalidGenesis.genesisHash = "genesis"

        for invalidFixture in [invalidExplicit, invalidImplicit, invalidCall, invalidGenesis] {
            assertFailure(invalidFixture, runtime: runtime, name: "InvalidHex")
        }
    }

    func testCallUnknownToRuntimeIsRejected() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        var fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)

        for undecodableCall in ["0xffff", "0x"] {
            fixture.callData = undecodableCall

            assertFailure(fixture, runtime: runtime, name: "DecodeError")
        }
    }

    func testExtensionsOutsideThePipelineAreIgnored() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        var fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)

        // neither is decoded: one belongs to another runtime, the other isn't even hex
        fixture.extensions.append(.init(id: ExtensionId.assetTxPayment, extra: "0xffffffff", additionalSigned: "0x"))
        fixture.extensions.append(.init(id: "AsScarcity", extra: "not hex", additionalSigned: "0x"))

        let resolution = try resolve(fixture, runtime: runtime)

        XCTAssertEqual(resolution.extensions.map(\.identifier), runtime.metadata.getSignedExtensions())
    }

    func testExtensionSuppliedTwiceIsRejected() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        var fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)
        fixture.extensions.append(DAppTxPayloadFixture.make(ExtensionId.nonce, extra: Data([0x1C])))

        assertFailure(fixture, runtime: runtime, name: "DecodeError")
    }

    func testSuppliedSignatureExtensionIsIgnored() throws {
        let runtime = try ExtrinsicGoldenRuntime.westendV16(customization: .init(formats: [5]))
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)
            .replacing(ExtensionId.verifySignature, extra: Data([0xFF, 0xFF]), additionalSigned: Data([0xFF]))

        let resolution = try resolve(fixture, runtime: runtime)

        XCTAssertTrue(resolution.extensions.first?.source.isSignature == true)
    }

    // MARK: Omitted extensions

    func testOmittedExtensionsTheWalletKnowsAreProvidedByWallet() throws {
        let runtime = try ExtrinsicGoldenRuntime.polkadotAssetHub()

        let walletIds = [
            ExtensionId.nonce,
            ExtensionId.mortality,
            ExtensionId.checkMetadataHash,
            ExtensionId.genesis,
            ExtensionId.specVersion,
            ExtensionId.txVersion,
            ExtensionId.assetTxPayment
        ]

        let fixture = try walletIds.reduce(DAppTxPayloadFixture.transfer(runtime: runtime)) { $0.removing($1) }

        let resolution = try resolve(fixture, runtime: runtime)

        XCTAssertEqual(resolution.extensions.map(\.identifier), runtime.metadata.getSignedExtensions())

        for identifier in walletIds {
            XCTAssertTrue(resolution.isProvidedByWallet(identifier), identifier)
        }

        let westend = try ExtrinsicGoldenRuntime.westend()
        let withoutTip = try DAppTxPayloadFixture.transfer(runtime: westend).removing(ExtensionId.txPayment)

        XCTAssertTrue(try resolve(withoutTip, runtime: westend).isProvidedByWallet(ExtensionId.txPayment))
    }

    func testOmittedZeroSizedExtensionIsLeftToRuntime() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)
            .removing("CheckWeight")
            .removing("CheckNonZeroSender")

        let resolution = try resolve(fixture, runtime: runtime)

        let sources = resolution.extensions.filter { ["CheckWeight", "CheckNonZeroSender"].contains($0.identifier) }

        XCTAssertEqual(sources.count, 2)
        XCTAssertTrue(sources.allSatisfy { $0.source.isRuntimeDefault })
    }

    func testOmittedExtensionWithValueIsMandatory() throws {
        let runtime = try ExtrinsicGoldenRuntime.avail()
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)

        // CheckAppId is a compact integer the wallet doesn't choose on behalf of a dApp
        XCTAssertThrowsError(try resolve(fixture.removing(AvailSignedExtension.checkAppId), runtime: runtime)) { error in
            XCTAssertEqual(
                error as? DAppCreateTransactionError,
                .missingMandatoryExtension(details: AvailSignedExtension.checkAppId)
            )
        }

        let withAppId = fixture.replacing(AvailSignedExtension.checkAppId, extra: Data([0x04]))

        XCTAssertEqual(
            try resolve(withAppId, runtime: runtime).supplied(for: AvailSignedExtension.checkAppId)?.rawExplicit,
            Data([0x04])
        )
    }

    // MARK: Extensions the app has no code for

    func testExtensionKnownOnlyToMetadataPassesWithItsBytes() throws {
        let runtime = try ExtrinsicGoldenRuntime.westendV16WithCustomExtensions()
        let fixture = try DAppTxPayloadFixture.customTransfer(runtime: runtime)

        let resolution = try resolve(fixture, runtime: runtime)
        let supplied = try XCTUnwrap(resolution.supplied(for: DAppTxPayloadCustomExtension.valueId))

        XCTAssertEqual(supplied.rawExplicit, DAppTxPayloadCustomExtension.valueExplicit)
        XCTAssertEqual(supplied.rawImplicit, DAppTxPayloadCustomExtension.valueImplicit)
        XCTAssertEqual(supplied.explicit, .stringValue("42"))

        // the same extension with bytes of a wrong shape
        let truncated = fixture.replacing(
            DAppTxPayloadCustomExtension.valueId,
            extra: Data([0x2A]),
            additionalSigned: DAppTxPayloadCustomExtension.valueImplicit
        )

        assertFailure(truncated, runtime: runtime, name: "DecodeError")
    }

    func testOmittedExtensionKnownOnlyToMetadata() throws {
        let runtime = try ExtrinsicGoldenRuntime.westendV16WithCustomExtensions()
        let fixture = try DAppTxPayloadFixture.customTransfer(runtime: runtime)

        // an optional explicit part with nothing to sign can be omitted
        let resolution = try resolve(fixture.removing(DAppTxPayloadCustomExtension.optionalId), runtime: runtime)
        let optionalSource = resolution.extensions.first { $0.identifier == DAppTxPayloadCustomExtension.optionalId }?.source

        XCTAssertTrue(optionalSource?.isRuntimeDefault == true)

        // a value the wallet can't invent
        assertFailure(fixture.removing(DAppTxPayloadCustomExtension.valueId), runtime: runtime, name: "MissingMandatoryExtension")

        // optional explicit part, but the signed payload expects a value
        assertFailure(
            fixture.removing(DAppTxPayloadCustomExtension.optionalWithImplicitId),
            runtime: runtime,
            name: "MissingMandatoryExtension"
        )
    }
}

private extension DAppTxPayloadExtensionResolverTests {
    func resolve(
        _ fixture: DAppTxPayloadFixture,
        runtime: ExtrinsicGoldenRuntime,
        metadataHash: Data? = nil
    ) throws -> DAppTxPayloadResolution {
        try resolver.resolve(
            payload: fixture.makePayload(),
            codingFactory: runtime.codingFactory,
            chainFacts: runtime.makeChainFacts(metadataHash: metadataHash)
        )
    }

    func assertFailure(
        _ fixture: DAppTxPayloadFixture,
        runtime: ExtrinsicGoldenRuntime,
        metadataHash: Data? = nil,
        name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try resolve(fixture, runtime: runtime, metadataHash: metadataHash),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual((error as? DAppCreateTransactionError)?.name, name, "\(error)", file: file, line: line)
        }
    }
}

extension DAppTxPayloadResolution.Source {
    var isSuppliedByDApp: Bool {
        if case .dApp = self { true } else { false }
    }

    var isSignature: Bool {
        if case .signature = self { true } else { false }
    }

    var isRuntimeDefault: Bool {
        if case .runtimeDefault = self { true } else { false }
    }
}
