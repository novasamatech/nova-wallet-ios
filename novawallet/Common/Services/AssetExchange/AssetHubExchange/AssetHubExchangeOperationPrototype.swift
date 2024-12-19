import Foundation
import Operation_iOS

final class AssetHubExchangeOperationPrototype: AssetExchangeBaseOperationPrototype {
    let host: AssetHubExchangeHostProtocol

    init(assetIn: ChainAsset, assetOut: ChainAsset, host: AssetHubExchangeHostProtocol) {
        self.host = host

        super.init(assetIn: assetIn, assetOut: assetOut)
    }
}

extension AssetHubExchangeOperationPrototype: AssetExchangeOperationPrototypeProtocol {
    func estimatedCostInUsdt(using converter: AssetExchageUsdtConverting) throws -> Decimal {
        guard let nativeAsset = assetIn.chain.utilityChainAsset() else {
            throw ChainModelFetchError.noAsset(assetId: AssetModel.utilityAssetId)
        }

        return converter.convertToUsdt(the: nativeAsset, decimalAmount: 0.015) ?? 0
    }

    func estimatedExecutionTimeWrapper() -> CompoundOperationWrapper<TimeInterval> {
        host.executionTimeEstimator.totalTimeWrapper(for: [host.chain.chainId])
    }
}
