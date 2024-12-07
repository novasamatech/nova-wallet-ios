import Foundation
import Operation_iOS

protocol AssetsExchangePathCostEstimating: AnyObject {
    func costEstimationWrapper(
        for path: AssetExchangeGraphPath,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<Balance>
}

enum AssetsExchangePathCostEstimatorError: Error {
    case amountConversion
}

final class AssetsExchangePathCostEstimator: AnyObject {
    let priceStore: AssetExchangePriceStoring
    let chainRegistry: ChainRegistryProtocol

    init(priceStore: AssetExchangePriceStoring, chainRegistry: ChainRegistryProtocol) {
        self.priceStore = priceStore
        self.chainRegistry = chainRegistry
    }

    private func deriveChainAsset(
        for operations: [AssetExchangeOperationPrototypeProtocol],
        direction: AssetConversion.Direction
    ) -> ChainAsset? {
        switch direction {
        case .sell:
            operations.last?.assetOut
        case .buy:
            operations.first?.assetIn
        }
    }

    private func deriveUsdtPrice() -> PriceData? {
        guard let chainAsset = chainRegistry.getChain(for: KnowChainId.statemint)?.chainAssetForSymbol("USDT") else {
            return nil
        }

        return priceStore.fetchPrice(for: chainAsset.chainAssetId)
    }

    private func convertToAssetAmount(
        using chainAsset: ChainAsset,
        costInUsdt: Decimal,
        usdtFiatRate: Decimal,
        assetFiatRate: Decimal
    ) throws -> Balance {
        guard assetFiatRate > 0 else {
            return 0
        }

        let assetCostDecimal = costInUsdt * usdtFiatRate / assetFiatRate

        guard let amount = assetCostDecimal.toSubstrateAmount(
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) else {
            throw AssetsExchangePathCostEstimatorError.amountConversion
        }

        return amount
    }
}

extension AssetsExchangePathCostEstimator: AssetsExchangePathCostEstimating {
    func costEstimationWrapper(
        for path: AssetExchangeGraphPath,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<Balance> {
        let operation = ClosureOperation<Balance> {
            guard let ustdFiatRate = self.deriveUsdtPrice()?.decimalRate else {
                return 0
            }

            let operations = try AssetExchangeOperationPrototypeFactory().createOperationPrototypes(from: path)

            let totalCostInUsdt = operations.reduce(Decimal(0)) { $0 + $1.estimatedCostInUsdt }

            guard
                let amountChainAsset = self.deriveChainAsset(
                    for: operations,
                    direction: direction
                ),
                let assetFiatRate = self.priceStore.fetchPrice(
                    for: amountChainAsset.chainAssetId
                )?.decimalRate else {
                return 0
            }

            return try self.convertToAssetAmount(
                using: amountChainAsset,
                costInUsdt: totalCostInUsdt,
                usdtFiatRate: ustdFiatRate,
                assetFiatRate: assetFiatRate
            )
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
