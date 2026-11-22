@testable import novawallet
import SubstrateSdk
import XCTest

/// The registry factory has to type every metadata version the app may have stored: v16 from now on,
/// v15 and v14 for the chains that offer nothing newer and for the items cached by earlier builds.
final class RuntimeTypeRegistryFactoryTests: XCTestCase {
    private let factory = RuntimeTypeRegistryFactory(logger: Logger.shared)

    private let westend = RuntimeProviderChain(
        chainId: KnowChainId.westend,
        typesUsage: .none,
        name: "Westend",
        isEthereumBased: false
    )

    func testDefaultTypingAcceptsMetadataV16() throws {
        let fixture = RuntimeMetadataFixture.polkadotAssetHub

        for rawMetadata in [try fixture.rawMetadata(version: 16), try Self.loadWestendV16()] {
            let info = try factory.createForMetadataAndDefaultTyping(
                chain: fixture.runtimeChain,
                runtimeMetadataItem: rawMetadata
            )

            XCTAssertTrue(info.runtimeMetadata is RuntimeMetadataV16)
            XCTAssertNoThrow(try encodeTransfer(with: info))
        }
    }

    func testDefaultTypingKeepsAcceptingOlderMetadata() throws {
        let fixture = RuntimeMetadataFixture.polkadotAssetHub

        let v15Info = try factory.createForMetadataAndDefaultTyping(
            chain: fixture.runtimeChain,
            runtimeMetadataItem: try fixture.rawMetadata(version: 15)
        )

        XCTAssertTrue(v15Info.runtimeMetadata is RuntimeMetadataV15)
        XCTAssertNoThrow(try encodeTransfer(with: v15Info))

        // the legacy call result is stored as it is, without the opaque wrapping
        let v14Info = try factory.createForMetadataAndDefaultTyping(
            chain: fixture.runtimeChain,
            runtimeMetadataItem: try Self.loadHex("polkadot-asset-hub-metadata", isOpaque: false)
        )

        XCTAssertTrue(v14Info.runtimeMetadata is RuntimeMetadataV14)
        XCTAssertNoThrow(try encodeTransfer(with: v14Info))
    }

    func testDefaultTypingRejectsMetadataWithoutTypes() throws {
        let container = RuntimeMetadataContainer(
            metaReserved: 0,
            runtimeMetadataVersion: 13,
            runtimeMetadata: .v13(RuntimeHelper.dummyRuntimeMetadata)
        )

        let rawMetadata = RawRuntimeMetadata(content: try container.scaleEncoded(), isOpaque: false)

        XCTAssertThrowsError(
            try factory.createForMetadataAndDefaultTyping(chain: westend, runtimeMetadataItem: rawMetadata)
        ) { error in
            guard case RuntimeTypeRegistryFactoryError.unsupportedRuntimeVersion = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testEveryTypingVariantAcceptsMetadataV16() throws {
        let rawMetadata = try Self.loadWestendV16()
        let chainTypes = try Self.loadTypes("runtime-westend")

        // typing of metadata with a type registry reads the versioned shape of a chain bundle from either file
        let variants = [
            try factory.createForMetadataAndDefaultTyping(chain: westend, runtimeMetadataItem: rawMetadata),
            try factory.createForChainTypes(chain: westend, runtimeMetadataItem: rawMetadata, chainTypes: chainTypes),
            try factory.createForCommonTypes(chain: westend, runtimeMetadataItem: rawMetadata, commonTypes: chainTypes),
            try factory.createForCommonAndChainTypes(
                chain: westend,
                runtimeMetadataItem: rawMetadata,
                commonTypes: try Self.loadTypes("runtime-default"),
                chainTypes: chainTypes
            )
        ]

        // a bundle applies from its runtime_id on, so the spec version of the metadata is used
        let specVersion = ExtrinsicGoldenRuntime.westendV16SpecVersion
        let expectedCall = try encodeTransfer(with: variants[0], specVersion: specVersion)

        for info in variants {
            XCTAssertTrue(info.runtimeMetadata is RuntimeMetadataV16)
            XCTAssertEqual(try encodeTransfer(with: info, specVersion: specVersion), expectedCall)
            XCTAssertEqual(info.runtimeMetadata.getSupportedFormatVersions(), [4, 5])
        }
    }

    func testCommonTypesFileIsTreatedTheSameForEveryMetadataVersion() throws {
        // the shared file has no versioning, which the typing of post-v14 metadata asks for:
        // the outcome doesn't depend on the metadata version
        let commonTypes = try Self.loadTypes("runtime-default")
        let fixture = RuntimeMetadataFixture.polkadotAssetHub

        for version: UInt32 in [15, 16] {
            XCTAssertThrowsError(
                try factory.createForCommonTypes(
                    chain: fixture.runtimeChain,
                    runtimeMetadataItem: try fixture.rawMetadata(version: version),
                    commonTypes: commonTypes
                )
            ) { error in
                XCTAssertEqual(String(describing: error), "missingVersioning")
            }
        }
    }

    func testChainTypesBundleIsAppliedToEveryMetadataVersion() throws {
        let avail = RuntimeProviderChain(
            chainId: KnowChainId.avail,
            typesUsage: .onlyOwn,
            name: "Avail",
            isEthereumBased: false
        )

        let availTypes = try Self.loadTypes("runtime-avail")

        // the bundle applies from its runtime_id on; this is the spec version of the Avail fixture
        let specVersion: UInt32 = 56

        // Avail itself offers metadata v15 at most, so its bundle meets v16 only on another runtime here
        let sources: [RuntimeContainerSourceProtocol] = [
            try Self.loadHex("avail-metadata", isOpaque: false),
            try RuntimeMetadataFixture.polkadotAssetHub.rawMetadata(version: 15),
            try RuntimeMetadataFixture.polkadotAssetHub.rawMetadata(version: 16)
        ]

        for source in sources {
            let info = try factory.createForChainTypes(chain: avail, runtimeMetadataItem: source, chainTypes: availTypes)

            // the alias comes from the bundle, no metadata declares it
            XCTAssertNotNil(info.typeRegistryCatalog.node(for: "Address", version: UInt64(specVersion)))
            XCTAssertNoThrow(try encodeTransfer(with: info, specVersion: specVersion))
        }
    }

    func testTypingOfV16MatchesV15OfTheSameRuntime() throws {
        for fixture in RuntimeMetadataFixture.all {
            let v15Info = try factory.createForMetadataAndDefaultTyping(
                chain: fixture.runtimeChain,
                runtimeMetadataItem: try fixture.rawMetadata(version: 15)
            )

            let v16Info = try factory.createForMetadataAndDefaultTyping(
                chain: fixture.runtimeChain,
                runtimeMetadataItem: try fixture.rawMetadata(version: 16)
            )

            XCTAssertEqual(try encodeTransfer(with: v16Info), try encodeTransfer(with: v15Info))
        }
    }
}

private extension RuntimeTypeRegistryFactoryTests {
    static func loadHex(_ name: String, isOpaque: Bool) throws -> RawRuntimeMetadata {
        guard let url = RuntimeHelper.testBundle.url(forResource: name, withExtension: "") else {
            throw RuntimeHelperError.invalidCatalogMetadataName
        }

        let hex = try String(contentsOf: url).trimmingCharacters(in: .whitespacesAndNewlines)

        return RawRuntimeMetadata(content: try Data(hexString: hex), isOpaque: isOpaque)
    }

    static func loadWestendV16() throws -> RawRuntimeMetadata {
        try loadHex("westend-v16-metadata", isOpaque: true)
    }

    static func loadTypes(_ name: String) throws -> Data {
        guard let url = RuntimeHelper.testBundle.url(forResource: name, withExtension: "json") else {
            throw RuntimeHelperError.invalidCatalogBaseName
        }

        return try Data(contentsOf: url)
    }

    func encodeTransfer(with info: RuntimeTypeRegistryInfo, specVersion: UInt32 = 1) throws -> String {
        let runtime = ExtrinsicGoldenRuntime(
            codingFactory: RuntimeCoderFactory(
                catalog: info.typeRegistryCatalog,
                specVersion: specVersion,
                txVersion: 1,
                metadata: info.runtimeMetadata
            )
        )

        let call = try ExtrinsicGolden.transferCall().toScaleCompatibleJSON(
            with: runtime.codingFactory.createRuntimeJsonContext().toRawContext()
        )

        return try runtime.encodeCall(call)
    }
}
