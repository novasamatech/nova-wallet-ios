import Foundation
import Operation_iOS

protocol AssetCanPayFeeWrapperFactoryProtocol {
    var operationQueue: OperationQueue { get }
    var chainRegistry: ChainRegistryProtocol { get }

    func createCanPayFeeWrapper(in chainAsset: ChainAsset) -> CompoundOperationWrapper<Bool>

    func createCanPayFeeFilterWrapper(
        for chainAssets: [ChainModel: [ChainAsset]]
    ) -> CompoundOperationWrapper<[ChainAsset]>
}

extension AssetCanPayFeeWrapperFactoryProtocol {
    func createAssetHubCanPayFee(for chainAsset: ChainAsset) -> CompoundOperationWrapper<Bool> {
        guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            return .createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return .createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        return AssetHubSwapOperationFactory(
            chain: chainAsset.chain,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        ).canPayFee(in: chainAsset.chainAssetId)
    }

    func createHydraCanPayFee(for chainAsset: ChainAsset) -> CompoundOperationWrapper<Bool> {
        guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            return .createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return .createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        return HydraTokensFactory.createWithDefaultPools(
            chain: chainAsset.chain,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        ).canPayFee(in: chainAsset.chainAssetId)
    }

    func createAssetHubCanPayFeeFilterWrapper(
        for chainAssets: (ChainModel, [ChainAsset])
    ) -> CompoundOperationWrapper<[ChainAsset]> {
        guard let connection = chainRegistry.getConnection(for: chainAssets.0.chainId) else {
            return .createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAssets.0.chainId) else {
            return .createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        return AssetHubSwapOperationFactory(
            chain: chainAssets.0,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        ).filterCanPayFee(for: chainAssets.1)
    }

    func createHydraCanPayFeeFilterWrapper(
        for chainAssets: (ChainModel, [ChainAsset])
    ) -> CompoundOperationWrapper<[ChainAsset]> {
        guard let connection = chainRegistry.getConnection(for: chainAssets.0.chainId) else {
            return .createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAssets.0.chainId) else {
            return .createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        return HydraTokensFactory.createWithDefaultPools(
            chain: chainAssets.0,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        ).filterCanPayFee(for: chainAssets.1)
    }
}

protocol AssetTransferAggregationFactoryProtocol: AssetCanPayFeeWrapperFactoryProtocol {}

enum AssetFeePaymentError: Error {
    case unavailableProvider(ChainModel)
}

final class AssetTransferAggregationFactory: AssetTransferAggregationFactoryProtocol {
    let operationQueue: OperationQueue
    let chainRegistry: ChainRegistryProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }

    func createCanPayFeeWrapper(in chainAsset: ChainAsset) -> CompoundOperationWrapper<Bool> {
        if chainAsset.chain.hasAssetHubFees {
            createAssetHubCanPayFee(for: chainAsset)
        } else if chainAsset.chain.hasHydrationFees {
            createHydraCanPayFee(for: chainAsset)
        } else {
            CompoundOperationWrapper.createWithError(
                AssetFeePaymentError.unavailableProvider(chainAsset.chain)
            )
        }
    }

    func createCanPayFeeFilterWrapper(
        for chainAssets: [ChainModel: [ChainAsset]]
    ) -> CompoundOperationWrapper<[ChainAsset]> {
        let operation = OperationCombiningService(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            chainAssets.compactMap { [weak self] chain, chainAssets in
                if chain.hasAssetHubFees {
                    self?.createAssetHubCanPayFeeFilterWrapper(for: (chain, chainAssets))
                } else if chain.hasHydrationFees {
                    self?.createHydraCanPayFeeFilterWrapper(for: (chain, chainAssets))
                } else {
                    nil
                }
            }
        }.longrunOperation()

        let resultOperation = ClosureOperation {
            try operation.extractNoCancellableResultData().flatMap { $0 }
        }

        resultOperation.addDependency(operation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: [operation]
        )
    }
}
