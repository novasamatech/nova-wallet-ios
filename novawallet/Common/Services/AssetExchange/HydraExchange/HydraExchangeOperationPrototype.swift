import Foundation
import Operation_iOS

final class HydraExchangeOperationPrototype: AssetExchangeBaseOperationPrototype {
    let host: HydraExchangeHostProtocol

    init(assetIn: ChainAsset, assetOut: ChainAsset, host: HydraExchangeHostProtocol) {
        self.host = host

        super.init(assetIn: assetIn, assetOut: assetOut)
    }
}

extension HydraExchangeOperationPrototype: AssetExchangeOperationPrototypeProtocol {
    func estimatedCostInUsdt(using converter: AssetExchageUsdtConverting) throws -> Decimal {
        guard let nativeAsset = assetIn.chain.utilityChainAsset() else {
            throw ChainModelFetchError.noAsset(assetId: AssetModel.utilityAssetId)
        }

        return converter.convertToUsdt(the: nativeAsset, decimalAmount: 0.5) ?? 0
    }

    func estimatedExecutionTimeWrapper() -> CompoundOperationWrapper<TimeInterval> {
        host.executionTimeEstimator.totalTimeWrapper(for: [host.chain.chainId])
    }
}
