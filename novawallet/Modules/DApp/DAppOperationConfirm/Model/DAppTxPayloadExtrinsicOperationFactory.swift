import Foundation
import SubstrateSdk
import Operation_iOS

struct DAppTxPayloadProcessedResult {
    let resolution: DAppTxPayloadResolution

    /**
     *   The asset the dApp pays the fee in when it isn't the native one and the wallet knows it
     */
    let feeAsset: ChainAsset?
}

protocol DAppTxPayloadExtrinsicFactoryProtocol: ExtrinsicBuilderOperationFactoryProtocol {
    func createProcessingWrapper() -> CompoundOperationWrapper<DAppTxPayloadProcessedResult>
}

/**
 *  Builds the extrinsic for a createTransaction request. The extensions supplied by the dApp go to
 *  the extrinsic as the bytes it sent once the resolver has verified them, the rest comes from the wallet.
 */
final class DAppTxPayloadExtrinsicOperationFactory {
    enum Constants {
        static let feeAssetIdField = "assetId"
    }

    struct Verification {
        let resolution: DAppTxPayloadResolution
        let metadataHash: Data?
    }

    struct Sender {
        let resolution: ExtrinsicSenderResolution
        let builder: ExtrinsicBuilderProtocol
        let walletOverriddenIds: Set<String>
    }

    struct Mortality {
        let era: Era
        let blockHash: String
    }

    struct WalletValues {
        let nonce: UInt32?
        let mortality: Mortality?
    }

    let payload: PolkadotExtensionTxPayload
    let chain: ChainModel
    let runtimeProvider: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let resolver: DAppTxPayloadExtensionResolving
    let metadataHashOperationFactory: MetadataHashOperationFactoryProtocol
    let senderResolvingFactory: ExtrinsicSenderResolutionFactoryProtocol
    let nonceOperationFactory: TransactionNonceOperationFactoryProtocol
    let eraOperationFactory: ExtrinsicEraOperationFactoryProtocol
    let blockHashOperationFactory: BlockHashOperationFactoryProtocol
    let signedExtensionFactory: ExtrinsicSignedExtensionFactoryProtocol
    let operationQueue: OperationQueue

    init(
        payload: PolkadotExtensionTxPayload,
        chain: ChainModel,
        runtimeProvider: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        resolver: DAppTxPayloadExtensionResolving,
        metadataHashOperationFactory: MetadataHashOperationFactoryProtocol,
        senderResolvingFactory: ExtrinsicSenderResolutionFactoryProtocol,
        nonceOperationFactory: TransactionNonceOperationFactoryProtocol,
        eraOperationFactory: ExtrinsicEraOperationFactoryProtocol,
        blockHashOperationFactory: BlockHashOperationFactoryProtocol,
        signedExtensionFactory: ExtrinsicSignedExtensionFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.payload = payload
        self.chain = chain
        self.runtimeProvider = runtimeProvider
        self.connection = connection
        self.resolver = resolver
        self.metadataHashOperationFactory = metadataHashOperationFactory
        self.senderResolvingFactory = senderResolvingFactory
        self.nonceOperationFactory = nonceOperationFactory
        self.eraOperationFactory = eraOperationFactory
        self.blockHashOperationFactory = blockHashOperationFactory
        self.signedExtensionFactory = signedExtensionFactory
        self.operationQueue = operationQueue
    }
}

// MARK: DAppTxPayloadExtrinsicFactoryProtocol

extension DAppTxPayloadExtrinsicOperationFactory: DAppTxPayloadExtrinsicFactoryProtocol {
    func createProcessingWrapper() -> CompoundOperationWrapper<DAppTxPayloadProcessedResult> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let verificationWrapper = createVerificationWrapper(dependingOn: codingFactoryOperation)

        verificationWrapper.addDependency(operations: [codingFactoryOperation])

        let mappingOperation = ClosureOperation<DAppTxPayloadProcessedResult> {
            let resolution = try verificationWrapper.targetOperation.extractNoCancellableResultData().resolution
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            return DAppTxPayloadProcessedResult(
                resolution: resolution,
                feeAsset: self.findFeeAsset(in: resolution, codingFactory: codingFactory)
            )
        }

        mappingOperation.addDependency(verificationWrapper.targetOperation)

        return verificationWrapper
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: mappingOperation)
    }

    /**
     *  The fee asset is not installed here: the dApp has already put it into its payment extension,
     *  which must reach the extrinsic unchanged.
     */
    func createWrapper(
        customClosure _: @escaping ExtrinsicBuilderIndexedClosure,
        indexes _: [Int],
        payingFeeIn _: ChainAssetId?,
        signingClosure: @escaping (Data, ExtrinsicSigningContext) throws -> Data
    ) -> CompoundOperationWrapper<ExtrinsicsCreationResult> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let verificationWrapper = createVerificationWrapper(dependingOn: codingFactoryOperation)

        verificationWrapper.addDependency(operations: [codingFactoryOperation])

        let senderWrapper = createSenderWrapper(
            dependingOn: verificationWrapper.targetOperation,
            codingFactoryOperation: codingFactoryOperation
        )

        senderWrapper.addDependency(wrapper: verificationWrapper)

        let walletValuesWrapper = createWalletValuesWrapper(
            dependingOn: verificationWrapper.targetOperation,
            senderOperation: senderWrapper.targetOperation
        )

        walletValuesWrapper.addDependency(wrapper: senderWrapper)

        let extrinsicOperation = ClosureOperation<ExtrinsicsCreationResult> {
            let extrinsic = try self.buildExtrinsic(
                verification: try verificationWrapper.targetOperation.extractNoCancellableResultData(),
                sender: try senderWrapper.targetOperation.extractNoCancellableResultData(),
                walletValues: try walletValuesWrapper.targetOperation.extractNoCancellableResultData(),
                codingFactory: try codingFactoryOperation.extractNoCancellableResultData(),
                signingClosure: signingClosure
            )

            let sender = try senderWrapper.targetOperation.extractNoCancellableResultData().resolution

            return ExtrinsicsCreationResult(extrinsics: [extrinsic], sender: sender)
        }

        extrinsicOperation.addDependency(walletValuesWrapper.targetOperation)

        return walletValuesWrapper
            .insertingHead(operations: senderWrapper.allOperations)
            .insertingHead(operations: verificationWrapper.allOperations)
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: extrinsicOperation)
    }

    func createDummySigner(for cryptoType: MultiassetCryptoType) throws -> DummySigner {
        try DummySigner(cryptoType: cryptoType)
    }
}

// MARK: Wrappers

private extension DAppTxPayloadExtrinsicOperationFactory {
    func createVerificationWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<Verification> {
        let metadataHashWrapper = metadataHashOperationFactory.createCheckMetadataHashWrapper(
            for: chain,
            connection: connection,
            runtimeProvider: runtimeProvider
        )

        let verificationOperation = ClosureOperation<Verification> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let metadataHash = try metadataHashWrapper.targetOperation.extractNoCancellableResultData()

            guard let genesisHash = self.chain.genesisHash else {
                throw CommonError.dataCorruption
            }

            let resolution = try self.resolver.resolve(
                payload: self.payload,
                codingFactory: codingFactory,
                chainFacts: DAppTxPayloadChainFacts(
                    genesisHash: genesisHash,
                    specVersion: codingFactory.specVersion,
                    transactionVersion: codingFactory.txVersion,
                    metadataHash: metadataHash
                )
            )

            return Verification(resolution: resolution, metadataHash: metadataHash)
        }

        verificationOperation.addDependency(metadataHashWrapper.targetOperation)

        return metadataHashWrapper.insertingTail(operation: verificationOperation)
    }

    func createSenderWrapper(
        dependingOn verificationOperation: BaseOperation<Verification>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<Sender> {
        let resolverWrapper = senderResolvingFactory.createWrapper()

        let senderOperation = ClosureOperation<Sender> {
            let verification = try verificationOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let resolver = try resolverWrapper.targetOperation.extractNoCancellableResultData()

            guard let genesisHash = self.chain.genesisHash else {
                throw CommonError.dataCorruption
            }

            let callBuilder = try ExtrinsicBuilder(
                extrinsicVersion: verification.resolution.extrinsicVersion,
                specVersion: codingFactory.specVersion,
                transactionVersion: codingFactory.txVersion,
                genesisHash: genesisHash.toHex(includePrefix: true)
            )
            .with(runtimeJsonContext: codingFactory.createRuntimeJsonContext())
            .adding(call: verification.resolution.call)

            let (sender, builders) = try resolver.resolveSender(wrapping: [callBuilder], codingFactory: codingFactory)

            guard let builder = builders.first else {
                throw CommonError.dataCorruption
            }

            try DAppTxPayloadSignerPolicy.ensureCanSign(
                verification.resolution.extrinsicVersion,
                signerType: sender.account.type
            )

            return Sender(
                resolution: sender,
                builder: builder,
                walletOverriddenIds: DAppTxPayloadSignerPolicy.walletOverriddenIds(
                    for: sender,
                    hasMetadataHash: verification.metadataHash != nil
                )
            )
        }

        senderOperation.addDependency(resolverWrapper.targetOperation)

        return resolverWrapper.insertingTail(operation: senderOperation)
    }

    /**
     *  A complete payload needs nothing from the node, so the nonce and the era are requested
     *  only when it is known the wallet has to provide them.
     */
    func createWalletValuesWrapper(
        dependingOn verificationOperation: BaseOperation<Verification>,
        senderOperation: BaseOperation<Sender>
    ) -> CompoundOperationWrapper<WalletValues> {
        OperationCombiningService<WalletValues>.compoundNonOptionalWrapper(operationQueue: operationQueue) {
            let resolution = try verificationOperation.extractNoCancellableResultData().resolution
            let sender = try senderOperation.extractNoCancellableResultData()

            let nonceId = Extrinsic.TransactionExtensionId.nonce
            let needsNonce = resolution.isProvidedByWallet(nonceId) || sender.walletOverriddenIds.contains(nonceId)

            let nonceWrapper: CompoundOperationWrapper<UInt32>? = if needsNonce {
                self.nonceOperationFactory.createWrapper(for: self.chain, connection: self.connection) {
                    sender.resolution.account.accountId
                }
            } else {
                nil
            }

            let needsMortality = resolution.isProvidedByWallet(Extrinsic.TransactionExtensionId.mortality)
            let mortalityWrapper: CompoundOperationWrapper<Mortality>? = if needsMortality {
                self.createMortalityWrapper()
            } else {
                nil
            }

            let mappingOperation = ClosureOperation<WalletValues> {
                WalletValues(
                    nonce: try nonceWrapper?.targetOperation.extractNoCancellableResultData(),
                    mortality: try mortalityWrapper?.targetOperation.extractNoCancellableResultData()
                )
            }

            mappingOperation.addDependencyIfExists(nonceWrapper?.targetOperation)
            mappingOperation.addDependencyIfExists(mortalityWrapper?.targetOperation)

            return CompoundOperationWrapper(targetOperation: mappingOperation)
                .insertingHeadIfExists(operations: nonceWrapper?.allOperations)
                .insertingHeadIfExists(operations: mortalityWrapper?.allOperations)
        }
    }

    func createMortalityWrapper() -> CompoundOperationWrapper<Mortality> {
        let eraWrapper = eraOperationFactory.createOperation(from: connection, runtimeService: runtimeProvider)

        let blockHashOperation = blockHashOperationFactory.createBlockHashOperation(connection: connection) {
            try eraWrapper.targetOperation.extractNoCancellableResultData().blockNumber
        }

        blockHashOperation.addDependency(eraWrapper.targetOperation)

        let mappingOperation = ClosureOperation<Mortality> {
            Mortality(
                era: try eraWrapper.targetOperation.extractNoCancellableResultData().extrinsicEra,
                blockHash: try blockHashOperation.extractNoCancellableResultData()
            )
        }

        mappingOperation.addDependency(blockHashOperation)

        return eraWrapper
            .insertingTail(operation: blockHashOperation)
            .insertingTail(operation: mappingOperation)
    }
}
