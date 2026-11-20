import Foundation
import SubstrateSdk

protocol DAppTxPayloadExtensionResolving {
    /**
     *  Verifies the payload against the wallet's runtime. Throws only `DAppCreateTransactionError`.
     */
    func resolve(
        payload: PolkadotExtensionTxPayload,
        codingFactory: RuntimeCoderFactoryProtocol,
        chainFacts: DAppTxPayloadChainFacts
    ) throws -> DAppTxPayloadResolution
}

/**
 *  Decides which extrinsic version a createTransaction payload asks for and takes each transaction
 *  extension of that version either from the dApp or from the wallet. Nothing the wallet can't decode
 *  and encode back to the same bytes with its own runtime passes.
 */
final class DAppTxPayloadExtensionResolver {}

extension DAppTxPayloadExtensionResolver {
    enum Constants {
        static let metadataHashDisabledMode = Data([0])
        static let metadataHashEnabledMode = Data([1])
        static let encodedNone = Data([0])
    }

    static let walletProvidedIds: Set<String> = [
        Extrinsic.TransactionExtensionId.nonce,
        Extrinsic.TransactionExtensionId.mortality,
        Extrinsic.TransactionExtensionId.checkMetadataHash,
        Extrinsic.TransactionExtensionId.genesis,
        Extrinsic.TransactionExtensionId.specVersion,
        Extrinsic.TransactionExtensionId.txVersion,
        Extrinsic.TransactionExtensionId.txPayment,
        Extrinsic.TransactionExtensionId.assetTxPayment
    ]

    struct Runtime {
        let codingFactory: RuntimeCoderFactoryProtocol
        let metadata: PostV14RuntimeMetadataProtocol
        let extraNode: ExtrinsicExtraNode
        let chainFacts: DAppTxPayloadChainFacts
        let extensionVersion: UInt8
    }
}

// MARK: DAppTxPayloadExtensionResolving

extension DAppTxPayloadExtensionResolver: DAppTxPayloadExtensionResolving {
    func resolve(
        payload: PolkadotExtensionTxPayload,
        codingFactory: RuntimeCoderFactoryProtocol,
        chainFacts: DAppTxPayloadChainFacts
    ) throws -> DAppTxPayloadResolution {
        guard
            let metadata = codingFactory.metadata as? PostV14RuntimeMetadataProtocol,
            let extraNode = codingFactory.getTypeNode(
                for: GenericType.extrinsicExtra.name
            ) as? ExtrinsicExtraNode else {
            throw DAppCreateTransactionError.decodeError(
                details: "the wallet's runtime doesn't describe transaction extensions"
            )
        }

        guard try decodeHex(payload.context.genesisHash, field: "genesisHash") == chainFacts.genesisHash else {
            throw DAppCreateTransactionError.decodeError(details: "genesisHash doesn't match the chain")
        }

        let call = try decodeCall(from: payload.callData, codingFactory: codingFactory)
        let extrinsicVersion = try resolveVersion(for: payload.txExtVersion, metadata: metadata)

        let runtime = Runtime(
            codingFactory: codingFactory,
            metadata: metadata,
            extraNode: extraNode,
            chainFacts: chainFacts,
            extensionVersion: extrinsicVersion.extensionVersion
        )

        let pipeline = try resolvePipeline(for: runtime)
        let suppliedById = Dictionary(grouping: payload.extensions, by: { $0.id })

        let extensions = try pipeline.map { descriptor in
            let source = try resolveSource(
                for: descriptor,
                supplied: suppliedById[descriptor.identifier] ?? [],
                runtime: runtime
            )

            return DAppTxPayloadResolution.Extension(identifier: descriptor.identifier, source: source)
        }

        try ensureExtrinsicKeepsSuppliedBytes(of: extensions, pipeline: pipeline, runtime: runtime)

        return DAppTxPayloadResolution(extrinsicVersion: extrinsicVersion, call: call, extensions: extensions)
    }
}

// MARK: Version and call

private extension DAppTxPayloadExtensionResolver {
    func resolveVersion(
        for txExtVersion: UInt?,
        metadata: PostV14RuntimeMetadataProtocol
    ) throws -> Extrinsic.Version {
        let requestedVersion = txExtVersion ?? UInt(Extrinsic.Version.baseExtensionVersion)
        let supportedFormats = metadata.getSupportedFormatVersions()

        // metadata before v16 doesn't list the formats: such a runtime is served with legacy extrinsics as before
        let supportsLegacyFormat = supportedFormats?.contains(Extrinsic.Version.legacyFormatNumber) ?? true

        if requestedVersion == UInt(Extrinsic.Version.baseExtensionVersion), supportsLegacyFormat {
            return .V4
        }

        guard
            let extensionVersion = UInt8(exactly: requestedVersion),
            let supportedFormats, supportedFormats.contains(Extrinsic.Version.generalFormatNumber),
            let pipelineIds = try? metadata.getSignedExtensions(forExtensionVersion: extensionVersion),
            pipelineIds.contains(Extrinsic.TransactionExtensionId.verifySignature) else {
            throw DAppCreateTransactionError.unsupportedTxExtensionVersion(
                details: "version \(requestedVersion) is not supported by the wallet's runtime"
            )
        }

        return .V5(extensionVersion: extensionVersion)
    }

    func resolvePipeline(for runtime: Runtime) throws -> [SignedExtensionV14] {
        do {
            return try runtime.metadata.postV14Extrinsic.signedExtensions(
                forExtensionVersion: runtime.extensionVersion
            )
        } catch {
            throw DAppCreateTransactionError.unsupportedTxExtensionVersion(
                details: "version \(runtime.extensionVersion) is not supported by the wallet's runtime"
            )
        }
    }

    func decodeCall(
        from hex: String,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> RuntimeCall<JSON> {
        let callData = try decodeHex(hex, field: "callData")

        return try decoding("callData") {
            let context = codingFactory.createRuntimeJsonContext().toRawContext()

            let decoder = try codingFactory.createDecoder(from: callData)
            let call: RuntimeCall<JSON> = try decoder.read(of: KnownType.call.name, with: context)

            let encoder = codingFactory.createEncoder()
            try encoder.append(call, ofType: KnownType.call.name, with: context)

            try ensureCanonical(
                "callData",
                remained: decoder.remained,
                original: callData,
                encoded: try encoder.encode()
            )

            return call
        }
    }
}

// MARK: Extensions

private extension DAppTxPayloadExtensionResolver {
    func resolveSource(
        for descriptor: SignedExtensionV14,
        supplied: [PolkadotExtensionTxPayload.Extension],
        runtime: Runtime
    ) throws -> DAppTxPayloadResolution.Source {
        let identifier = descriptor.identifier

        guard identifier != Extrinsic.TransactionExtensionId.verifySignature else {
            return .signature
        }

        guard supplied.count <= 1 else {
            throw DAppCreateTransactionError.decodeError(details: "\(identifier) is supplied more than once")
        }

        if let suppliedExtension = supplied.first {
            let decoded = try decodeSupplied(suppliedExtension, descriptor: descriptor, runtime: runtime)
            try ensureMatchesWalletValues(decoded, identifier: identifier, runtime: runtime)

            return .dApp(decoded)
        }

        if Self.walletProvidedIds.contains(identifier) {
            return .wallet
        }

        // the extrinsic builder leaves out an extension it has no value for, so the hole must be a valid encoding
        guard canBeOmitted(descriptor, runtime: runtime) else {
            throw DAppCreateTransactionError.missingMandatoryExtension(details: identifier)
        }

        return .runtimeDefault
    }

    func decodeSupplied(
        _ supplied: PolkadotExtensionTxPayload.Extension,
        descriptor: SignedExtensionV14,
        runtime: Runtime
    ) throws -> DAppTxPayloadResolution.SuppliedExtension {
        let identifier = descriptor.identifier
        let rawExplicit = try decodeHex(supplied.extra, field: "\(identifier).extra")
        let rawImplicit = try decodeHex(supplied.additionalSigned, field: "\(identifier).additionalSigned")
        let coder = explicitCoder(for: identifier, runtime: runtime)

        let explicit: JSON? = try decoding("\(identifier).extra") {
            let decoder = try runtime.codingFactory.createDecoder(from: rawExplicit)
            var store = ExtrinsicExtra()

            try coder.decodeIncludedInExtrinsic(
                to: &store,
                extensionVersion: runtime.extensionVersion,
                decoder: decoder
            )

            let encoder = runtime.codingFactory.createEncoder()

            try coder.encodeIncludedInExtrinsic(
                from: store,
                extensionVersion: runtime.extensionVersion,
                encoder: encoder
            )

            try ensureCanonical(
                "\(identifier).extra",
                remained: decoder.remained,
                original: rawExplicit,
                encoded: try encoder.encode()
            )

            return store[identifier]
        }

        let implicit: JSON = try decoding("\(identifier).additionalSigned") {
            let type = String(descriptor.additionalSigned)
            let decoder = try runtime.codingFactory.createDecoder(from: rawImplicit)
            let value = try decoder.read(type: type)

            let encoder = runtime.codingFactory.createEncoder()
            try encoder.append(json: value, type: type)

            try ensureCanonical(
                "\(identifier).additionalSigned",
                remained: decoder.remained,
                original: rawImplicit,
                encoded: try encoder.encode()
            )

            return value
        }

        return DAppTxPayloadResolution.SuppliedExtension(
            rawExplicit: rawExplicit,
            rawImplicit: rawImplicit,
            explicit: explicit,
            implicit: implicit,
            coder: coder
        )
    }

    func ensureMatchesWalletValues(
        _ supplied: DAppTxPayloadResolution.SuppliedExtension,
        identifier: String,
        runtime: Runtime
    ) throws {
        let walletExtension: TransactionExtending

        switch identifier {
        case Extrinsic.TransactionExtensionId.genesis:
            walletExtension = TransactionExtension.CheckGenesis(
                genesisHash: runtime.chainFacts.genesisHash.toHex(includePrefix: true)
            )
        case Extrinsic.TransactionExtensionId.specVersion:
            walletExtension = TransactionExtension.CheckSpecVersion(specVersion: runtime.chainFacts.specVersion)
        case Extrinsic.TransactionExtensionId.txVersion:
            walletExtension = TransactionExtension.CheckTxVersion(
                transactionVersion: runtime.chainFacts.transactionVersion
            )
        case Extrinsic.TransactionExtensionId.checkMetadataHash:
            walletExtension = try createWalletMetadataHash(forMode: supplied.rawExplicit, runtime: runtime)
        default:
            return
        }

        let walletImplicit = try decoding(identifier) {
            try walletExtension.implicit(
                using: runtime.codingFactory,
                metadata: runtime.metadata,
                extensionVersion: runtime.extensionVersion,
                context: runtime.codingFactory.createRuntimeJsonContext()
            )
        }

        guard supplied.rawImplicit == walletImplicit ?? Data() else {
            throw DAppCreateTransactionError.decodeError(
                details: "\(identifier) doesn't match the value the wallet has for the chain"
            )
        }
    }

    func createWalletMetadataHash(
        forMode mode: Data,
        runtime: Runtime
    ) throws -> TransactionExtension.CheckMetadataHash {
        switch mode {
        case Constants.metadataHashDisabledMode:
            return TransactionExtension.CheckMetadataHash(mode: .disabled)
        case Constants.metadataHashEnabledMode:
            guard let metadataHash = runtime.chainFacts.metadataHash else {
                throw DAppCreateTransactionError.decodeError(
                    details: "the wallet has no metadata hash to verify CheckMetadataHash"
                )
            }

            return TransactionExtension.CheckMetadataHash(mode: .enabled(metadataHash))
        default:
            throw DAppCreateTransactionError.decodeError(details: "CheckMetadataHash has an unknown mode")
        }
    }

    func canBeOmitted(_ descriptor: SignedExtensionV14, runtime: Runtime) -> Bool {
        let explicitType = String(descriptor.type)

        let acceptsNoExplicit = isZeroSized(explicitType, runtime: runtime) ||
            runtime.codingFactory.createEncoder().canEncodeOptional(for: explicitType)

        return acceptsNoExplicit && isZeroSized(String(descriptor.additionalSigned), runtime: runtime)
    }

    func isZeroSized(_ type: String, runtime: Runtime) -> Bool {
        do {
            let value = try runtime.codingFactory.createDecoder(from: Data()).read(type: type)

            let encoder = runtime.codingFactory.createEncoder()
            try encoder.append(json: value, type: type)

            return try encoder.encode().isEmpty
        } catch {
            return false
        }
    }
}
