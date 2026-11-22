import BigInt
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

/// createTransaction against the runtimes the app builds from real metadata v16 with `RuntimeTypeRegistryFactory`:
/// which extrinsic format a request resolves to, and the general (v5) transaction of a runtime that has one.
final class DAppCreateTransactionV16Tests: XCTestCase {
    private typealias ExtensionId = Extrinsic.TransactionExtensionId

    /// The extension version Polkadot Asset Hub signs general transactions with
    private static let generalExtensionVersion: UInt8 = 1

    private let assetHub = RuntimeMetadataFixture.polkadotAssetHub
    private let resolver = DAppTxPayloadExtensionResolver()
    private let operationQueue = OperationQueue()

    // MARK: Version

    func testBaseExtensionVersionResolvesToLegacyExtrinsicOnRealRuntimes() throws {
        let runtimes = [
            try assetHub.runtime(version: 16),
            try RuntimeMetadataFixture.polkadot.runtime(version: 16),
            try makeWestendRuntime()
        ]

        for runtime in runtimes {
            XCTAssertEqual(runtime.metadata.getSupportedFormatVersions(), [4, 5])

            var fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)

            let resolution = try resolve(fixture, runtime: runtime)

            XCTAssertEqual(resolution.extrinsicVersion, .V4)
            XCTAssertEqual(
                resolution.extensions.map(\.identifier),
                try runtime.metadata.getSignedExtensions(forExtensionVersion: 0)
            )
            XCTAssertNil(resolution.extensions.first { $0.identifier == ExtensionId.verifySignature })

            fixture.txExtVersion = nil

            XCTAssertEqual(try resolve(fixture, runtime: runtime).extrinsicVersion, .V4)
        }
    }

    func testLegacyResolutionIsTheOneOfMetadataV15() throws {
        for fixture in RuntimeMetadataFixture.all {
            let v15Runtime = try fixture.runtime(version: 15)
            let v16Runtime = try fixture.runtime(version: 16)

            let payload = try DAppTxPayloadFixture.transfer(runtime: v15Runtime)

            let v15Resolution = try resolve(payload, runtime: v15Runtime)
            let v16Resolution = try resolve(payload, runtime: v16Runtime)

            XCTAssertEqual(v16Resolution.extrinsicVersion, v15Resolution.extrinsicVersion)
            XCTAssertEqual(v16Resolution.extensions.map(\.identifier), v15Resolution.extensions.map(\.identifier))
            XCTAssertEqual(v16Resolution.call.moduleName, v15Resolution.call.moduleName)
            XCTAssertEqual(v16Resolution.call.callName, v15Resolution.call.callName)
        }
    }

    func testRuntimesWithOneExtensionVersionHaveNoGeneralTransaction() throws {
        for runtime in [try RuntimeMetadataFixture.polkadot.runtime(version: 16), try makeWestendRuntime()] {
            XCTAssertEqual(runtime.metadata.getSupportedExtensionVersions(), [0])

            var fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)
            fixture.txExtVersion = UInt(Self.generalExtensionVersion)

            assertFailure(fixture, runtime: runtime, name: "UnsupportedTxExtensionVersion")
        }
    }

    func testAssetHubExtensionVersionWithSignatureResolvesToGeneralTransaction() throws {
        let runtime = try assetHub.runtime(version: 16)
        let fixture = try makeGeneralTransfer(runtime: runtime)

        let resolution = try resolve(fixture, runtime: runtime)
        let pipeline = try runtime.metadata.getSignedExtensions(forExtensionVersion: Self.generalExtensionVersion)

        XCTAssertEqual(resolution.extrinsicVersion, .V5(extensionVersion: Self.generalExtensionVersion))
        XCTAssertEqual(resolution.extensions.map(\.identifier), pipeline)

        let signature = try XCTUnwrap(resolution.extensions.first { $0.identifier == ExtensionId.verifySignature })

        XCTAssertTrue(signature.source.isSignature)

        // an extension version the runtime doesn't list
        var unknownVersion = fixture
        unknownVersion.txExtVersion = 2

        assertFailure(unknownVersion, runtime: runtime, name: "UnsupportedTxExtensionVersion")

        // the same request can't be served from metadata v15, which knows the base version only
        assertFailure(fixture, runtime: try assetHub.runtime(version: 15), name: "UnsupportedTxExtensionVersion")
    }

    func testRuntimeWithoutLegacyFormatResolvesBaseVersionToGeneralTransaction() throws {
        // Asset Hub as it would be after dropping format 4: its general transaction set is the only one
        let runtime = try makeAssetHubRuntime(formats: [5], onlyGeneralSetAs: 0)

        XCTAssertEqual(runtime.metadata.getSupportedFormatVersions(), [5])

        var fixture = try makeGeneralTransfer(runtime: runtime, extensionVersion: 0)

        XCTAssertEqual(try resolve(fixture, runtime: runtime).extrinsicVersion, .V5(extensionVersion: 0))

        fixture.txExtVersion = nil

        XCTAssertEqual(try resolve(fixture, runtime: runtime).extrinsicVersion, .V5(extensionVersion: 0))
    }

    func testRuntimeWithoutGeneralFormatRefusesItsExtensionVersion() throws {
        let runtime = try makeAssetHubRuntime(formats: [4], onlyGeneralSetAs: nil)
        let fixture = try makeGeneralTransfer(runtime: runtime)

        assertFailure(fixture, runtime: runtime, name: "UnsupportedTxExtensionVersion")
    }

    func testAssetHubExtensionWithValueCantBeLeftOut() throws {
        let runtime = try assetHub.runtime(version: 16)
        let fixture = try makeGeneralTransfer(runtime: runtime)

        // options are read as None by the runtime
        XCTAssertNoThrow(try resolve(fixture.removing("AsPgas").removing("AsDotnsGateway"), runtime: runtime))

        // a flag has no default the wallet could sign for the dApp
        assertFailure(fixture.removing("RestrictOrigins"), runtime: runtime, name: "MissingMandatoryExtension")
    }

    // MARK: Extrinsic

    func testLegacyExtrinsicIsTheOneBuiltWithMetadataV15() throws {
        for fixture in RuntimeMetadataFixture.all {
            let v15Runtime = try fixture.runtime(version: 15)
            let v16Runtime = try fixture.runtime(version: 16)

            let payload = try DAppTxPayloadFixture.transfer(runtime: v15Runtime)

            let v15Built = try build(payload, runtime: v15Runtime)
            let v16Built = try build(payload, runtime: v16Runtime)

            XCTAssertEqual(v16Built.extrinsic, v15Built.extrinsic, fixture.name)
            XCTAssertEqual(v16Built.signedPayload, v15Built.signedPayload, fixture.name)
            XCTAssertNotNil(try v16Runtime.decodeExtrinsic(v16Built.extrinsic).getSignedExtrinsic())
        }
    }

    func testAssetHubGeneralTransactionIsSignedThroughVerifyMultiSignature() throws {
        let runtime = try assetHub.runtime(version: 16)
        let fixture = try makeGeneralTransfer(runtime: runtime)

        let built = try build(fixture, runtime: runtime)
        let expected = try assembleGeneralTransaction(for: fixture, runtime: runtime)

        XCTAssertEqual(built.signedPayload, expected.signedPayload)
        XCTAssertEqual(built.extrinsic, expected.extrinsic)

        guard case let .generalTransaction(general) = try runtime.decodeExtrinsic(built.extrinsic) else {
            return XCTFail("General transaction expected")
        }

        XCTAssertEqual(general.extensionVersion, Self.generalExtensionVersion)
        XCTAssertEqual(try runtime.encodeCall(general.call), fixture.callData)
    }
}

private extension DAppCreateTransactionV16Tests {
    struct Built {
        let extrinsic: String
        let signedPayload: String
    }

    func makeWestendRuntime() throws -> ExtrinsicGoldenRuntime {
        guard let url = RuntimeHelper.testBundle.url(forResource: "westend-v16-metadata", withExtension: "") else {
            throw RuntimeHelperError.invalidCatalogMetadataName
        }

        let hex = try String(contentsOf: url).trimmingCharacters(in: .whitespacesAndNewlines)

        return try RuntimeMetadataFixture(
            name: "westend",
            chainId: KnowChainId.westend,
            specName: "westend",
            specVersion: ExtrinsicGoldenRuntime.westendV16SpecVersion,
            transactionVersion: ExtrinsicGoldenRuntime.westendV16TransactionVersion
        ).makeRuntime(from: RawRuntimeMetadata(content: try Data(hexString: hex), isOpaque: true))
    }

    /// The real Asset Hub metadata with other extrinsic formats, encoded back and typed by the registry factory.
    /// `onlyGeneralSetAs` leaves a single extension set, the one with `VerifyMultiSignature`, under that version.
    func makeAssetHubRuntime(formats: [UInt8], onlyGeneralSetAs version: UInt8?) throws -> ExtrinsicGoldenRuntime {
        guard let metadata = try assetHub.postV14Metadata(version: 16) as? RuntimeMetadataV16 else {
            throw RuntimeHelperError.invalidCatalogMetadataName
        }

        let extrinsic = metadata.extrinsic

        let sets = try version.map { version in
            let generalSet = try XCTUnwrap(
                extrinsic.transactionExtensionsByVersion.first { $0.extensionVersion == Self.generalExtensionVersion }
            )

            return [TransactionExtensionsVersionV16(extensionVersion: version, extensionIndexes: generalSet.extensionIndexes)]
        } ?? extrinsic.transactionExtensionsByVersion

        let container = RuntimeMetadataContainer(
            metaReserved: 0,
            runtimeMetadataVersion: 16,
            runtimeMetadata: .v16(
                RuntimeMetadataV16(
                    types: metadata.types,
                    pallets: metadata.pallets,
                    extrinsic: ExtrinsicMetadataV16(
                        versions: formats,
                        addressType: extrinsic.addressType,
                        callType: extrinsic.callType,
                        signatureType: extrinsic.signatureType,
                        transactionExtensionsByVersion: sets,
                        transactionExtensions: extrinsic.transactionExtensions
                    ),
                    apis: metadata.apis
                )
            )
        )

        return try assetHub.makeRuntime(
            from: RawRuntimeMetadata(content: try container.scaleEncoded(), isOpaque: false)
        )
    }

    /// The golden transfer with every extension of Asset Hub's general transaction set, the way a dApp sends it.
    /// The extensions `DAppTxPayloadFixture` has no value for are options and a flag: sent as None and false.
    func makeGeneralTransfer(
        runtime: ExtrinsicGoldenRuntime,
        extensionVersion: UInt8 = generalExtensionVersion
    ) throws -> DAppTxPayloadFixture {
        try DAppTxPayloadFixture.transfer(runtime: runtime, extensionVersion: extensionVersion)
            .replacing("AsPgas", extra: Data([0]))
            .replacing("AsDotnsGateway", extra: Data([0]))
            .replacing("RestrictOrigins", extra: Data([0]))
    }

    func resolve(_ fixture: DAppTxPayloadFixture, runtime: ExtrinsicGoldenRuntime) throws -> DAppTxPayloadResolution {
        try resolver.resolve(
            payload: fixture.makePayload(),
            codingFactory: runtime.codingFactory,
            chainFacts: runtime.makeChainFacts()
        )
    }

    func assertFailure(
        _ fixture: DAppTxPayloadFixture,
        runtime: ExtrinsicGoldenRuntime,
        name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try resolve(fixture, runtime: runtime), file: file, line: line) { error in
            XCTAssertEqual((error as? DAppCreateTransactionError)?.name, name, "\(error)", file: file, line: line)
        }
    }

    func build(_ fixture: DAppTxPayloadFixture, runtime: ExtrinsicGoldenRuntime) throws -> Built {
        let chain = try ExtrinsicGoldenRuntime.makeChain()

        let factory = DAppTxPayloadExtrinsicOperationFactory(
            payload: fixture.makePayload(),
            chain: chain,
            runtimeProvider: RuntimeCodingServiceStub(factory: runtime.codingFactory),
            connection: DAppNonceEngineStub(nonce: 0),
            resolver: resolver,
            metadataHashOperationFactory: DAppMetadataHashFactoryStub(metadataHash: nil),
            senderResolvingFactory: ExtrinsicSenderResolutionFactoryStub(accountId: ExtrinsicGolden.senderId, chain: chain),
            nonceOperationFactory: TransactionNonceOperationFactory(),
            eraOperationFactory: PresetEraOperationFactory(
                parameters: ExtrinsicEraParameters(blockNumber: 100, extrinsicEra: ExtrinsicGolden.era)
            ),
            blockHashOperationFactory: DAppBlockHashFactoryStub(),
            signedExtensionFactory: ExtrinsicSignedExtensionFactory(),
            operationQueue: operationQueue
        )

        var signedPayload = Data()

        let wrapper = factory.createWrapper(
            customClosure: { builder, _ in builder },
            indexes: [0],
            payingFeeIn: nil,
            signingClosure: { payload, _ in
                signedPayload = payload
                return ExtrinsicGolden.sr25519Signature
            }
        )

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        let extrinsic = try XCTUnwrap(wrapper.targetOperation.extractNoCancellableResultData().extrinsics.first)

        return Built(
            extrinsic: extrinsic.toHex(includePrefix: true),
            signedPayload: signedPayload.toHex(includePrefix: true)
        )
    }

    /// What Asset Hub expects from a general transaction, assembled from the bytes of the payload alone.
    /// The signature covers blake2-256 of extension version | call | explicit parts of the extensions that
    /// follow `VerifyMultiSignature` | their implicit parts; the extensions in front of it are not signed.
    func assembleGeneralTransaction(for fixture: DAppTxPayloadFixture, runtime: ExtrinsicGoldenRuntime) throws -> Built {
        let pipeline = try runtime.metadata.getSignedExtensions(forExtensionVersion: Self.generalExtensionVersion)
        let signatureIndex = try XCTUnwrap(pipeline.firstIndex(of: ExtensionId.verifySignature))

        func join(_ identifiers: ArraySlice<String>, _ part: KeyPath<PolkadotExtensionTxPayload.Extension, String>) throws -> Data {
            try identifiers.reduce(into: Data()) { result, identifier in
                let supplied = try XCTUnwrap(fixture.extensions.first { $0.id == identifier }, identifier)
                result.append(try Data(hexString: supplied[keyPath: part]))
            }
        }

        let leadingExplicits = try join(pipeline[..<signatureIndex], \.extra)
        let signedExplicits = try join(pipeline[(signatureIndex + 1)...], \.extra)
        let signedImplicits = try join(pipeline[(signatureIndex + 1)...], \.additionalSigned)

        let callData = try Data(hexString: fixture.callData)
        let extensionVersion = Data([Self.generalExtensionVersion])

        let signedPayload = try (extensionVersion + callData + signedExplicits + signedImplicits).blake2b32()

        // Asset Hub declares VerifySignature as Disabled = 0, Signed = 1; Sr25519 is 1 in MultiSignature
        let signature = Data([0x01, 0x01]) + ExtrinsicGolden.sr25519Signature + ExtrinsicGolden.senderId

        // general transaction of format 5 | extension version | explicit parts in the order of the set | call
        let body = Data([0x45]) + extensionVersion + leadingExplicits + signature + signedExplicits + callData
        let extrinsic = try DAppTxPayloadFixture.scale(BigUInt(body.count)) + body

        return Built(
            extrinsic: extrinsic.toHex(includePrefix: true),
            signedPayload: signedPayload.toHex(includePrefix: true)
        )
    }
}
