import Foundation
import Operation_iOS

protocol AssetsExchangePathCostEstimating: AnyObject {
    func costEstimationWrapper(
        for path: AssetExchangeGraphPath
    ) -> CompoundOperationWrapper<AssetsExchangePathCost>
}

struct AssetsExchangePathCost {
    let amountInAssetIn: Balance
    let amountInAssetOut: Balance

    static var zero: AssetsExchangePathCost {
        AssetsExchangePathCost(amountInAssetIn: 0, amountInAssetOut: 0)
    }
}

final class AssetsExchangePathCostEstimator {
    let priceStore: AssetExchangePriceStoring
    let chainRegistry: ChainRegistryProtocol

    init(priceStore: AssetExchangePriceStoring, chainRegistry: ChainRegistryProtocol) {
        self.priceStore = priceStore
        self.chainRegistry = chainRegistry
    }
}

extension AssetsExchangePathCostEstimator: AssetsExchangePathCostEstimating {
    func costEstimationWrapper(
        for path: AssetExchangeGraphPath
    ) -> CompoundOperationWrapper<AssetsExchangePathCost> {
        let operation = ClosureOperation<AssetsExchangePathCost> {
            guard let usdtTiedAsset = self.chainRegistry.getChain(
                for: KnowChainId.polkadotAssetHub
            )?.chainAssetForSymbol("USDT") else {
                return .zero
            }

            let usdtConverter = AssetExchageUsdtConverter(
                priceStore: self.priceStore,
                usdtTiedAsset: usdtTiedAsset.chainAssetId
            )

            let operations = try AssetExchangeOperationPrototypeFactory().createOperationPrototypes(from: path)

            let totalCostInUsdt = try operations.reduce(Decimal(0)) { total, operation in
                let estimatedCostInUsdt = try operation.estimatedCostInUsdt(using: usdtConverter)

                return total + estimatedCostInUsdt
            }

            guard
                let assetIn = operations.first?.assetIn,
                let assetOut = operations.last?.assetOut else {
                return .zero
            }

            let assetInCost = usdtConverter.convertToAssetInPlankFromUsdt(
                amount: totalCostInUsdt,
                asset: assetIn
            ) ?? .zero

            let assetOutCost = usdtConverter.convertToAssetInPlankFromUsdt(
                amount: totalCostInUsdt,
                asset: assetOut
            ) ?? .zero

            return AssetsExchangePathCost(amountInAssetIn: assetInCost, amountInAssetOut: assetOutCost)
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
