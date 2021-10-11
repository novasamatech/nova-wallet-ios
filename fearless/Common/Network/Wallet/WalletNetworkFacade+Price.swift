import Foundation
import RobinHood
import CommonWallet

extension WalletNetworkFacade {
    func fetchPriceOperation(assets: [WalletAsset]) -> CompoundOperationWrapper<[String: Price]> {
        let priceIdMapping: [String: WalletAsset] = assets.reduce(
            into: [:]
        ) { result, walletAsset in
            guard
                let chainAssetId = ChainAssetId(walletId: walletAsset.identifier),
                let chain = chains[chainAssetId.chainId],
                let asset = chain.assets.first(where: { $0.assetId == chainAssetId.assetId }),
                let priceId = asset.priceId else {
                return
            }

            result[priceId] = walletAsset
        }

        let allPriceIds = [String](priceIdMapping.keys)

        let priceOperation = coingeckoOperationFactory.fetchPriceOperation(for: allPriceIds)

        let mappingOperation: BaseOperation<[String: Price]> = ClosureOperation {
            let priceDataList = try priceOperation.extractNoCancellableResultData()

            guard priceDataList.count == allPriceIds.count else {
                throw BaseOperationError.unexpectedDependentResult
            }

            return zip(allPriceIds, priceDataList).reduce(into: [:]) { result, pair in
                guard let asset = priceIdMapping[pair.0] else {
                    return
                }

                let priceData = pair.1

                let price = Price(
                    lastValue: Decimal(string: priceData.price) ?? 0.0,
                    change: (priceData.usdDayChange ?? 0.0) / 100.0
                )

                result[asset.identifier] = price
            }
        }

        mappingOperation.addDependency(priceOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [priceOperation]
        )
    }
}
