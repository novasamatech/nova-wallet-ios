import Foundation
import Operation_iOS
import SubstrateSdk

final class AssetHubExchangeFeeSupportFetcher {
    let swapOperationFactory: AssetHubSwapOperationFactoryProtocol
    let chain: ChainModel

    init(
        chain: ChainModel,
        swapOperationFactory: AssetHubSwapOperationFactoryProtocol
    ) {
        self.chain = chain
        self.swapOperationFactory = swapOperationFactory
    }
}

extension AssetHubExchangeFeeSupportFetcher: AssetExchangeFeeSupportFetching {
    var identifier: String { "asset-hub-\(chain.chainId)" }

    func createFeeSupportWrapper() -> CompoundOperationWrapper<AssetExchangeFeeSupporting> {
        guard let utilityAssetId = chain.utilityChainAsset()?.chainAssetId else {
            return .createWithError(ChainModelFetchError.noAsset(assetId: AssetModel.utilityAssetId))
        }

        let availableDirectionsWrapper = swapOperationFactory.availableDirections()

        let mappingOperation = ClosureOperation<AssetExchangeFeeSupporting> {
            let availableDirections = try availableDirectionsWrapper.targetOperation.extractNoCancellableResultData()

            let supportedAssetIds = availableDirections
                .filter { $0.value.contains(utilityAssetId) }
                .keys

            return AssetExchangeFeeSupport(supportedAssets: Set(supportedAssetIds))
        }

        mappingOperation.addDependency(availableDirectionsWrapper.targetOperation)

        return availableDirectionsWrapper.insertingTail(operation: mappingOperation)
    }
}
