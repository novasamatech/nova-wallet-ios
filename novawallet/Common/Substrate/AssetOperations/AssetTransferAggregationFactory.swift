import Foundation
import Operation_iOS

protocol AssetCanPayFeeWrapperFactoryProtocol {
    var operationQueue: OperationQueue { get }
    var chainRegistry: ChainRegistryProtocol { get }

    func createCanPayFeeWrapper(in chainAsset: ChainAsset) -> CompoundOperationWrapper<Bool>
}

extension AssetCanPayFeeWrapperFactoryProtocol {
    func createAssetHubCanPayFee(for chainAsset: ChainAsset) -> CompoundOperationWrapper<Bool> {
        do {
            let connection = try chainRegistry.getConnectionOrError(for: chainAsset.chain.chainId)

            let runtimeService = try chainRegistry.getRuntimeProviderOrError(for: chainAsset.chain.chainId)

            return AssetHubSwapOperationFactory(
                chain: chainAsset.chain,
                runtimeService: runtimeService,
                connection: connection,
                operationQueue: operationQueue
            ).canPayFee(in: chainAsset.chainAssetId)
        } catch {
            return .createWithError(error)
        }
    }

    func createHydraCanPayFee(for chainAsset: ChainAsset) -> CompoundOperationWrapper<Bool> {
        do {
            let connection = try chainRegistry.getConnectionOrError(for: chainAsset.chain.chainId)

            let runtimeService = try chainRegistry.getRuntimeProviderOrError(for: chainAsset.chain.chainId)

            return HydraTokensFactory.createWithDefaultPools(
                chain: chainAsset.chain,
                runtimeService: runtimeService,
                connection: connection,
                operationQueue: operationQueue
            ).canPayFee(in: chainAsset.chainAssetId)
        } catch {
            return .createWithError(error)
        }
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
            return createAssetHubCanPayFee(for: chainAsset)
        } else if chainAsset.chain.hasHydrationFees {
            return createHydraCanPayFee(for: chainAsset)
        } else {
            return CompoundOperationWrapper.createWithError(
                AssetFeePaymentError.unavailableProvider(chainAsset.chain)
            )
        }
    }
}
