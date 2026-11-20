import BigInt
import Foundation
@testable import novawallet
import Operation_iOS
import SubstrateSdk

/// A createTransaction payload assembled extension by extension. The bytes are written here with plain SCALE,
/// not with the wallet's extension classes, so they stand for what an independent dApp would send.
struct DAppTxPayloadFixture {
    struct Values {
        var nonce: UInt32 = ExtrinsicGolden.nonce
        var era: Era = ExtrinsicGolden.era
        var blockHash: String = ExtrinsicGolden.blockHash
        var genesisHash: String = ExtrinsicGolden.genesisHash
        var tip = BigUInt(0)
        var metadataHash: Data?
        var specVersion: UInt32?
        var transactionVersion: UInt32?
    }

    var callData: String
    var txExtVersion: UInt? = 0
    var genesisHash: String = ExtrinsicGolden.genesisHash
    var extensions: [PolkadotExtensionTxPayload.Extension]

    /// The transfer of `ExtrinsicGolden` with every extension of the pipeline, mirroring `ExtrinsicGoldenRuntime.makeBuilder`.
    static func transfer(
        runtime: ExtrinsicGoldenRuntime,
        extensionVersion: UInt8 = 0,
        values: Values = Values()
    ) throws -> DAppTxPayloadFixture {
        let callJson = try ExtrinsicGolden.transferCall().toScaleCompatibleJSON(
            with: runtime.codingFactory.createRuntimeJsonContext().toRawContext()
        )

        let identifiers = try runtime.metadata.getSignedExtensions(forExtensionVersion: extensionVersion)

        return try DAppTxPayloadFixture(
            callData: runtime.encodeCall(callJson),
            txExtVersion: UInt(extensionVersion),
            extensions: identifiers.map { try makeExtension($0, runtime: runtime, values: values) }
        )
    }

    static func makeExtension(
        _ identifier: String,
        runtime: ExtrinsicGoldenRuntime,
        values: Values
    ) throws -> PolkadotExtensionTxPayload.Extension {
        let extra: Data
        let additionalSigned: Data

        switch identifier {
        case Extrinsic.TransactionExtensionId.specVersion:
            extra = Data()
            additionalSigned = littleEndian(values.specVersion ?? runtime.codingFactory.specVersion)
        case Extrinsic.TransactionExtensionId.txVersion:
            extra = Data()
            additionalSigned = littleEndian(values.transactionVersion ?? runtime.codingFactory.txVersion)
        case Extrinsic.TransactionExtensionId.genesis:
            extra = Data()
            additionalSigned = try Data(hexString: values.genesisHash)
        case Extrinsic.TransactionExtensionId.mortality:
            extra = try scale(values.era)
            additionalSigned = try Data(hexString: values.blockHash)
        case Extrinsic.TransactionExtensionId.nonce:
            extra = try scale(BigUInt(values.nonce))
            additionalSigned = Data()
        case Extrinsic.TransactionExtensionId.txPayment:
            extra = try scale(values.tip)
            additionalSigned = Data()
        case Extrinsic.TransactionExtensionId.assetTxPayment:
            // the tip and no asset: the fee is paid in the native token
            extra = try scale(values.tip) + Data([0])
            additionalSigned = Data()
        case Extrinsic.TransactionExtensionId.checkMetadataHash:
            extra = Data([values.metadataHash != nil ? 1 : 0])
            additionalSigned = values.metadataHash.map { Data([1]) + $0 } ?? Data([0])
        default:
            extra = Data()
            additionalSigned = Data()
        }

        return make(identifier, extra: extra, additionalSigned: additionalSigned)
    }

    static func make(
        _ identifier: String,
        extra: Data,
        additionalSigned: Data = Data()
    ) -> PolkadotExtensionTxPayload.Extension {
        PolkadotExtensionTxPayload.Extension(
            id: identifier,
            extra: extra.toHex(includePrefix: true),
            additionalSigned: additionalSigned.toHex(includePrefix: true)
        )
    }

    static func scale<T: ScaleEncodable>(_ value: T) throws -> Data {
        let encoder = ScaleEncoder()
        try value.encode(scaleEncoder: encoder)

        return encoder.encode()
    }

    static func littleEndian(_ value: UInt32) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    func replacing(_ identifier: String, extra: Data, additionalSigned: Data = Data()) -> DAppTxPayloadFixture {
        var fixture = removing(identifier)
        fixture.extensions.append(Self.make(identifier, extra: extra, additionalSigned: additionalSigned))

        return fixture
    }

    func removing(_ identifier: String) -> DAppTxPayloadFixture {
        var fixture = self
        fixture.extensions.removeAll { $0.id == identifier }

        return fixture
    }

    func makePayload() -> PolkadotExtensionTxPayload {
        PolkadotExtensionTxPayload(
            version: PolkadotExtensionTxPayload.supportedVersion,
            signer: nil,
            callData: callData,
            extensions: extensions,
            txExtVersion: txExtVersion,
            context: PolkadotExtensionTxPayload.Context(
                token: nil,
                bestBlockHeight: 100,
                bestBlockHash: ExtrinsicGolden.blockHash,
                genesisHash: genesisHash
            )
        )
    }

    /// The payload the way the JS bridge delivers it to the confirmation.
    func makeRequestJSON() throws -> JSON {
        let payload: [String: Any] = [
            "version": Int(PolkadotExtensionTxPayload.supportedVersion),
            "signer": NSNull(),
            "callData": callData,
            "extensions": extensions.map { ["id": $0.id, "extra": $0.extra, "additionalSigned": $0.additionalSigned] },
            "txExtVersion": txExtVersion.map { Int($0) as Any } ?? NSNull(),
            "context": [
                "token": NSNull(),
                "bestBlockHeight": 100,
                "bestBlockHash": ExtrinsicGolden.blockHash,
                "genesisHash": genesisHash
            ]
        ]

        return try JSONDecoder().decode(JSON.self, from: JSONSerialization.data(withJSONObject: payload))
    }
}

extension ExtrinsicGoldenRuntime {
    func makeChainFacts(metadataHash: Data? = nil) throws -> DAppTxPayloadChainFacts {
        DAppTxPayloadChainFacts(
            genesisHash: try Data(hexString: ExtrinsicGolden.genesisHash),
            specVersion: codingFactory.specVersion,
            transactionVersion: codingFactory.txVersion,
            metadataHash: metadataHash
        )
    }

    /// A chain whose genesis is the one of `ExtrinsicGolden`, so the wallet's value matches the golden payloads.
    static func makeChain() throws -> ChainModel {
        ChainModelGenerator.generateChain(
            defaultChainId: try Data(hexString: ExtrinsicGolden.genesisHash).toHex(),
            generatingAssets: 1,
            addressPrefix: 42
        )
    }
}

/// Changes applied to the real Westend metadata v16 fixture. No runtime the app has a fixture for declares
/// `VerifyMultiSignature`, so the extension is added by hand, typed as pallet-verify-signature of polkadot-sdk
/// defines it; the formats and the extension sets are replaced to reach the cases real chains don't have yet.
struct DAppTxPayloadV16Customization {
    static let verifySignatureTypeId: SiLookupId = 1_000_000

    /// The extrinsic formats the runtime declares
    var formats: [UInt8] = [4, 5]

    /// The identifiers of the extensions each extension version consists of, in order.
    /// Nil keeps the single set of the fixture with `VerifyMultiSignature` in front of it.
    var extensionSets: [UInt8: [String]]?

    /// Extensions the fixture doesn't have, described with the fixture's types
    var customExtensions: [SignedExtensionV14] = []

    func apply(to metadata: RuntimeMetadataV16) throws -> RuntimeMetadataV16 {
        let emptyTupleId = try Self.findEmptyTupleId(in: metadata.types)
        let signatureId = try Self.findTypeId(in: metadata.types, path: ["sp_runtime", "MultiSignature"])
        let accountId = try Self.findTypeId(in: metadata.types, path: ["sp_core", "crypto", "AccountId32"])

        let verifySignatureType = RuntimeType(
            path: ["pallet_verify_signature", "extension", "VerifySignature"],
            parameters: [],
            typeDefinition: .variant(
                RuntimeTypeVariant(variants: [
                    RuntimeTypeVariantItem(name: "Signed", fields: [
                        RuntimeTypeField(name: "signature", type: signatureId, typeName: nil, docs: []),
                        RuntimeTypeField(name: "account", type: accountId, typeName: nil, docs: [])
                    ], index: 0, docs: []),
                    RuntimeTypeVariantItem(name: "Disabled", fields: [], index: 1, docs: [])
                ])
            ),
            docs: []
        )

        let verifySignature = TransactionExtensionMetadataV16(
            identifier: Extrinsic.TransactionExtensionId.verifySignature,
            type: Self.verifySignatureTypeId,
            implicit: emptyTupleId
        )

        let fixtureExtensions = metadata.extrinsic.transactionExtensions
        let allExtensions = [verifySignature] + fixtureExtensions + customExtensions.map {
            TransactionExtensionMetadataV16(identifier: $0.identifier, type: $0.type, implicit: $0.additionalSigned)
        }

        let sets = extensionSets ?? [0: allExtensions.map(\.identifier)]

        let versions = try sets.keys.sorted().map { version in
            let indexes = try (sets[version] ?? []).map { identifier in
                guard let index = allExtensions.firstIndex(where: { $0.identifier == identifier }) else {
                    throw CommonError.dataCorruption
                }

                return UInt32(index)
            }

            return TransactionExtensionsVersionV16(extensionVersion: version, extensionIndexes: indexes)
        }

        return RuntimeMetadataV16(
            types: RuntimeTypesLookup(
                types: metadata.types.types + [
                    try Self.makePortableType(Self.verifySignatureTypeId, verifySignatureType)
                ]
            ),
            pallets: metadata.pallets,
            extrinsic: ExtrinsicMetadataV16(
                versions: formats,
                addressType: metadata.extrinsic.addressType,
                callType: metadata.extrinsic.callType,
                signatureType: metadata.extrinsic.signatureType,
                transactionExtensionsByVersion: versions,
                transactionExtensions: allExtensions
            ),
            apis: metadata.apis
        )
    }

    private static func findTypeId(in lookup: RuntimeTypesLookup, path: [String]) throws -> SiLookupId {
        guard let type = lookup.types.first(where: { $0.type.path == path }) else {
            throw CommonError.dataCorruption
        }

        return type.identifier
    }

    private static func findEmptyTupleId(in lookup: RuntimeTypesLookup) throws -> SiLookupId {
        let emptyTuple = lookup.types.first { type in
            if case let .tuple(tuple) = type.type.typeDefinition {
                return tuple.components.isEmpty
            } else {
                return false
            }
        }

        guard let emptyTuple else {
            throw CommonError.dataCorruption
        }

        return emptyTuple.identifier
    }

    // PortableType has no public initializer, so it is created the way the metadata itself is read
    private static func makePortableType(_ identifier: SiLookupId, _ type: RuntimeType) throws -> PortableType {
        let encoder = ScaleEncoder()
        try BigUInt(identifier).encode(scaleEncoder: encoder)
        try type.encode(scaleEncoder: encoder)

        return try PortableType(scaleDecoder: ScaleDecoder(data: encoder.encode()))
    }
}

extension ExtrinsicGoldenRuntime {
    static let westendV16SpecVersion: UInt32 = 1_020_000
    static let westendV16TransactionVersion: UInt32 = 27

    /// Westend as metadata v16: the fixture substrate-sdk-ios tests its v16 decoding with, typed the way
    /// `RuntimeTypeRegistryFactory` types v14/v15 metadata (the app itself doesn't request v16 yet).
    static func westendV16(
        customization: DAppTxPayloadV16Customization? = nil
    ) throws -> ExtrinsicGoldenRuntime {
        guard let url = RuntimeHelper.testBundle.url(forResource: "westend-v16-metadata", withExtension: "") else {
            throw RuntimeHelperError.invalidCatalogMetadataName
        }

        let hex = try String(contentsOf: url).trimmingCharacters(in: .whitespacesAndNewlines)
        let container = try RuntimeMetadataContainer.createFromOpaque(data: try Data(hexString: hex))

        guard case let .v16(fixtureMetadata) = container.runtimeMetadata else {
            throw RuntimeHelperError.invalidCatalogMetadataName
        }

        let metadata = try customization?.apply(to: fixtureMetadata) ?? fixtureMetadata

        let augmentation = RuntimeAugmentationFactory().createSubstrateAugmentation(for: metadata)
        let signedExtensionFactory = ExtrinsicSignedExtensionFacade().createFactory(for: KnowChainId.westend)

        let catalog = try TypeRegistryCatalog.createFromSiDefinition(
            runtimeMetadata: metadata,
            additionalNodes: augmentation.additionalNodes.nodes,
            customExtensions: signedExtensionFactory.createCoders(for: metadata),
            customTypeMapper: CustomSiMappers.all,
            customNameMapper: ScaleInfoCamelCaseMapper()
        )

        return ExtrinsicGoldenRuntime(
            codingFactory: RuntimeCoderFactory(
                catalog: catalog,
                specVersion: westendV16SpecVersion,
                txVersion: westendV16TransactionVersion,
                metadata: metadata
            )
        )
    }

    /// `VerifyMultiSignature` followed by every extension the Westend metadata v16 fixture declares.
    static func westendV16ExtensionIds() throws -> [String] {
        [Extrinsic.TransactionExtensionId.verifySignature] + (try westendV16().metadata.getSignedExtensions())
    }
}

/// Extensions the app has neither a class nor a coder for: only the metadata describes them.
enum DAppTxPayloadCustomExtension {
    static let valueId = "AsScarcity"
    static let optionalId = "OptionalHint"
    static let optionalWithImplicitId = "OptionalHintWithImplicit"

    static let valueExplicit = Data([0x2A, 0x00, 0x00, 0x00])
    static let valueImplicit = Data(repeating: 0x77, count: 32)
    static let optionalImplicit = Data([0x01, 0x00, 0x00, 0x00])
}

extension ExtrinsicGoldenRuntime {
    /// The Westend metadata v16 fixture extended with `DAppTxPayloadCustomExtension`, typed with what the
    /// fixture's registry already has: u32 with a signed H256, Option<H256> with nothing to sign and
    /// Option<H256> with a signed u32.
    static func westendV16WithCustomExtensions(formats: [UInt8] = [4, 5]) throws -> ExtrinsicGoldenRuntime {
        guard let metadata = try westendV16().metadata as? PostV14RuntimeMetadataProtocol else {
            throw CommonError.dataCorruption
        }

        let extensions = metadata.postV14Extrinsic.signedExtensions

        func find(_ identifier: String) throws -> SignedExtensionV14 {
            guard let fixtureExtension = extensions.first(where: { $0.identifier == identifier }) else {
                throw CommonError.dataCorruption
            }

            return fixtureExtension
        }

        let u32Type = try find(Extrinsic.TransactionExtensionId.specVersion).additionalSigned
        let hashType = try find(Extrinsic.TransactionExtensionId.genesis).additionalSigned
        let optionalHashType = try find(Extrinsic.TransactionExtensionId.checkMetadataHash).additionalSigned
        let unitType = try find(Extrinsic.TransactionExtensionId.nonce).additionalSigned

        let customExtensions = [
            SignedExtensionV14(
                identifier: DAppTxPayloadCustomExtension.valueId,
                type: u32Type,
                additionalSigned: hashType
            ),
            SignedExtensionV14(
                identifier: DAppTxPayloadCustomExtension.optionalId,
                type: optionalHashType,
                additionalSigned: unitType
            ),
            SignedExtensionV14(
                identifier: DAppTxPayloadCustomExtension.optionalWithImplicitId,
                type: optionalHashType,
                additionalSigned: u32Type
            )
        ]

        return try westendV16(
            customization: .init(
                formats: formats,
                extensionSets: [0: try westendV16ExtensionIds() + customExtensions.map(\.identifier)],
                customExtensions: customExtensions
            )
        )
    }
}

extension DAppTxPayloadFixture {
    /// The transfer for `westendV16WithCustomExtensions` where every custom extension carries a valid value.
    static func customTransfer(runtime: ExtrinsicGoldenRuntime) throws -> DAppTxPayloadFixture {
        try transfer(runtime: runtime)
            .replacing(
                DAppTxPayloadCustomExtension.valueId,
                extra: DAppTxPayloadCustomExtension.valueExplicit,
                additionalSigned: DAppTxPayloadCustomExtension.valueImplicit
            )
            .replacing(DAppTxPayloadCustomExtension.optionalId, extra: Data([0]))
            .replacing(
                DAppTxPayloadCustomExtension.optionalWithImplicitId,
                extra: Data([0]),
                additionalSigned: DAppTxPayloadCustomExtension.optionalImplicit
            )
    }
}

final class DAppBlockHashFactoryStub: BlockHashOperationFactoryProtocol {
    let blockHash: String

    init(blockHash: String = ExtrinsicGolden.blockHash) {
        self.blockHash = blockHash
    }

    func createBlockHashOperation(
        connection _: JSONRPCEngine,
        for _: @escaping () throws -> BlockNumber
    ) -> BaseOperation<String> {
        ClosureOperation { self.blockHash }
    }

    func createBestBlockHashWrapper(connection _: JSONRPCEngine) -> CompoundOperationWrapper<BlockHashData> {
        .createWithError(CommonError.undefined)
    }
}
