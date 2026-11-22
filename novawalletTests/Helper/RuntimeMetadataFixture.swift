import Foundation
@testable import novawallet
import SubstrateSdk

/// Real metadata of one runtime in versions 15 and 16, stored the way the app stores it: the bytes
/// `Metadata_metadata_at_version` returns (`Option<OpaqueMetadata>`), not hex.
///
/// Fetched on 2026-11-22, both versions of a chain at the same spec version:
/// - Polkadot Asset Hub: `wss://asset-hub-polkadot-rpc.n.dwellir.com`, `statemint` spec 2005003, tx 15.
///   Declares extension versions 0 and 1; version 1 has `VerifyMultiSignature`.
/// - Polkadot: `wss://apps-rpc.polkadot.io`, `polkadot` spec 2005003, tx 26. Extension version 0 only.
struct RuntimeMetadataFixture {
    let name: String
    let chainId: ChainModel.Id
    let specName: String
    let specVersion: UInt32
    let transactionVersion: UInt32

    static let polkadotAssetHub = RuntimeMetadataFixture(
        name: "polkadot-asset-hub",
        chainId: KnowChainId.polkadotAssetHub,
        specName: "statemint",
        specVersion: 2_005_003,
        transactionVersion: 15
    )

    static let polkadot = RuntimeMetadataFixture(
        name: "polkadot",
        chainId: KnowChainId.polkadot,
        specName: "polkadot",
        specVersion: 2_005_003,
        transactionVersion: 26
    )

    static let all = [polkadotAssetHub, polkadot]

    // parsing a blob takes about half a second, so each runtime is built once per test run
    private static var runtimes: [String: ExtrinsicGoldenRuntime] = [:]
    private static let lock = NSLock()

    var runtimeChain: RuntimeProviderChain {
        RuntimeProviderChain(chainId: chainId, typesUsage: .none, name: name, isEthereumBased: false)
    }

    func rawMetadata(version: UInt32) throws -> RawRuntimeMetadata {
        let resource = "\(name)-v\(version)-opaque-metadata"

        guard let url = RuntimeHelper.testBundle.url(forResource: resource, withExtension: "") else {
            throw RuntimeHelperError.invalidCatalogMetadataName
        }

        return RawRuntimeMetadata(content: try Data(contentsOf: url), isOpaque: true)
    }

    func metadataItem(version: UInt32, localMigratorVersion: UInt32 = RuntimeLocalVersion.latest) throws -> RuntimeMetadataItem {
        RuntimeMetadataItem(
            chain: chainId,
            version: specVersion,
            txVersion: transactionVersion,
            localMigratorVersion: localMigratorVersion,
            opaque: true,
            metadata: try rawMetadata(version: version).content
        )
    }

    /// The runtime the app gets from the stored metadata: built by `RuntimeTypeRegistryFactory`, as `RuntimeProvider` does.
    func runtime(version: UInt32) throws -> ExtrinsicGoldenRuntime {
        Self.lock.lock()

        defer {
            Self.lock.unlock()
        }

        let key = "\(name)-\(version)"

        if let runtime = Self.runtimes[key] {
            return runtime
        }

        let runtime = try makeRuntime(from: rawMetadata(version: version))
        Self.runtimes[key] = runtime

        return runtime
    }

    func makeRuntime(from rawMetadata: RuntimeContainerSourceProtocol) throws -> ExtrinsicGoldenRuntime {
        let info = try RuntimeTypeRegistryFactory(logger: Logger.shared).createForMetadataAndDefaultTyping(
            chain: runtimeChain,
            runtimeMetadataItem: rawMetadata
        )

        return ExtrinsicGoldenRuntime(
            codingFactory: RuntimeCoderFactory(
                catalog: info.typeRegistryCatalog,
                specVersion: specVersion,
                txVersion: transactionVersion,
                metadata: info.runtimeMetadata
            )
        )
    }

    func postV14Metadata(version: UInt32) throws -> PostV14RuntimeMetadataProtocol {
        guard let metadata = try runtime(version: version).metadata as? PostV14RuntimeMetadataProtocol else {
            throw RuntimeHelperError.invalidCatalogMetadataName
        }

        return metadata
    }

    /// The chain model the metadata hash is generated for: prefix, token and decimals of the real chain
    func makeChain() -> ChainModel {
        let asset = ChainModelGenerator.generateAssetWithId(0, symbol: "DOT", assetPresicion: 10)

        return ChainModelGenerator.generateChain(assets: [asset], defaultChainId: chainId, addressPrefix: 0)
    }
}
