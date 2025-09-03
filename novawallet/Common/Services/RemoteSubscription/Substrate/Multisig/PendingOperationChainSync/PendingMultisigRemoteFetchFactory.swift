import Foundation
import Operation_iOS
import SubstrateSdk

protocol PendingMultisigRemoteFetchFactoryProtocol {
    func createFetchWrapper() -> CompoundOperationWrapper<MultisigPendingOperationsMap>
}

final class PendingMultisigRemoteFetchFactory {
    private let multisigAccountId: AccountId
    private let chain: ChainModel
    private let chainRegistry: ChainRegistryProtocol
    private let pendingCallHashesOperationFactory: MultisigStorageOperationFactoryProtocol
    private let blockTimeOperationFactory: BlockTimeOperationFactoryProtocol
    private let blockNumberOperationFactory: BlockNumberOperationFactoryProtocol
    private let offchainFactory: OffchainMultisigOperationsFactoryProtocol
    private let operationManager: OperationManagerProtocol

    init(
        multisigAccountId: AccountId,
        chain: ChainModel,
        chainRegistry: ChainRegistryProtocol,
        pendingCallHashesOperationFactory: MultisigStorageOperationFactoryProtocol,
        blockTimeOperationFactory: BlockTimeOperationFactoryProtocol,
        blockNumberOperationFactory: BlockNumberOperationFactoryProtocol,
        configProvider: GlobalConfigProviding,
        operationManager: OperationManagerProtocol
    ) {
        self.multisigAccountId = multisigAccountId
        self.chain = chain
        self.chainRegistry = chainRegistry
        self.pendingCallHashesOperationFactory = pendingCallHashesOperationFactory
        self.blockTimeOperationFactory = blockTimeOperationFactory
        self.blockNumberOperationFactory = blockNumberOperationFactory
        self.operationManager = operationManager
        offchainFactory = OffchainMultisigOperationsFactoryFacade(
            configProvider: configProvider,
            chainId: chain.chainId,
            operationManager: operationManager
        )
    }
}

// MARK: - Private

private extension PendingMultisigRemoteFetchFactory {
    func createOnchainOperationsFetchWrapper() -> CompoundOperationWrapper<OnchainOperations> {
        do {
            let connection = try chainRegistry.getConnectionOrError(for: chain.chainId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chain.chainId)

            return pendingCallHashesOperationFactory.fetchPendingOperations(
                for: multisigAccountId,
                connection: connection,
                runtimeProvider: runtimeProvider
            )
        } catch {
            return .createWithError(error)
        }
    }

    func createOffchainOperationsFetchWrapper(
        dependsOn onchainOperationsWrapper: CompoundOperationWrapper<OnchainOperations>
    ) -> CompoundOperationWrapper<OffchainOperations> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: operationManager
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let callHashes = try onchainOperationsWrapper
                .targetOperation
                .extractNoCancellableResultData()
                .keys

            guard let apiURL = chain.externalApis?.getApis(for: .multisig)?.first?.url else {
                return .createWithResult([:])
            }

            return offchainFactory.createFetchOffChainOperationInfo(
                for: multisigAccountId,
                callHashes: Set(callHashes)
            )
        }
    }

    func createPendingOperations(
        with onchainOperations: OnchainOperations,
        offchainOperations: OffchainOperations,
        blockTime: BlockTime,
        blockNumber: BlockNumber
    ) -> MultisigPendingOperationsMap {
        onchainOperations.reduce(into: [:]) { acc, keyValue in
            let callHash = keyValue.key
            let operationDefinition = keyValue.value

            let timestamp = if let timestamp = offchainOperations[callHash]?.timestamp {
                UInt64(timestamp)
            } else {
                BlockTimestampEstimator.estimateTimestamp(
                    for: operationDefinition.timepoint.height,
                    currentBlock: blockNumber,
                    blockTimeInMillis: blockTime
                )
            }

            let operation = Multisig.PendingOperation(
                call: offchainOperations[callHash]?.callData,
                callHash: callHash,
                timestamp: timestamp,
                multisigAccountId: multisigAccountId,
                chainId: chain.chainId,
                multisigDefinition: .init(from: operationDefinition)
            )

            acc[operation.createKey()] = operation
        }
    }

    func createBlockTimeWrapper() -> CompoundOperationWrapper<BlockTime> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chain.chainId)
            return blockTimeOperationFactory.createExpectedBlockTimeWrapper(from: runtimeProvider)
        } catch {
            return .createWithError(error)
        }
    }
}

// MARK: - PendingMultisigRemoteFetchFactoryProtocol

extension PendingMultisigRemoteFetchFactory: PendingMultisigRemoteFetchFactoryProtocol {
    func createFetchWrapper() -> CompoundOperationWrapper<MultisigPendingOperationsMap> {
        let onchainOperationsWrapper = createOnchainOperationsFetchWrapper()
        let offchainOperationsWrapper = createOffchainOperationsFetchWrapper(dependsOn: onchainOperationsWrapper)
        let blockTimeWrapper = createBlockTimeWrapper()
        let blockNumberWrapper = blockNumberOperationFactory.createWrapper(for: chain.chainId)

        let mapOperation: BaseOperation<MultisigPendingOperationsMap>
        mapOperation = ClosureOperation { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let blockTime = try blockTimeWrapper.targetOperation.extractNoCancellableResultData()
            let blockNumber = try blockNumberWrapper.targetOperation.extractNoCancellableResultData()

            return createPendingOperations(
                with: try onchainOperationsWrapper.targetOperation.extractNoCancellableResultData(),
                offchainOperations: try offchainOperationsWrapper.targetOperation.extractNoCancellableResultData(),
                blockTime: blockTime,
                blockNumber: blockNumber
            )
        }

        offchainOperationsWrapper.addDependency(wrapper: onchainOperationsWrapper)
        mapOperation.addDependency(offchainOperationsWrapper.targetOperation)
        mapOperation.addDependency(blockTimeWrapper.targetOperation)
        mapOperation.addDependency(blockNumberWrapper.targetOperation)

        return offchainOperationsWrapper
            .insertingHead(operations: blockTimeWrapper.allOperations)
            .insertingHead(operations: blockNumberWrapper.allOperations)
            .insertingHead(operations: onchainOperationsWrapper.allOperations)
            .insertingTail(operation: mapOperation)
    }
}

// MARK: - Private types

private typealias OnchainOperations = [Substrate.CallHash: MultisigPallet.MultisigDefinition]
private typealias OffchainOperations = [Substrate.CallHash: OffChainMultisigInfo]
