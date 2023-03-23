import Foundation
import RobinHood
import CommonWallet

extension WalletNetworkFacade {
    func fetchPriceOperation(
        assets: [WalletAsset],
        currency: Currency
    ) -> CompoundOperationWrapper<[String: Price]> {
        let priceIdMapping: [String: WalletAsset] = assets.reduce(
            into: [:]
        ) { result, walletAsset in
            guard
                let chainAssetId = ChainAssetId(walletId: walletAsset.identifier),
                let chain = chains[chainAssetId.chainId],
                let asset = chain.assets.first(where: { $0.assetId == chainAssetId.assetId }),
                let assetPriceId = asset.priceId else {
                return
            }

            let priceId = PriceData.createIdentifier(for: assetPriceId, currencyId: currency.id)

            result[priceId] = walletAsset
        }

        guard !priceIdMapping.isEmpty else {
            return CompoundOperationWrapper.createWithResult([:])
        }

        let mapper = PriceDataMapper()
        let repository = storageFacade.createRepository(
            filter: NSPredicate.pricesByIds([String](priceIdMapping.keys)),
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let priceOperation = repository.fetchAllOperation(with: .init())

        let mappingOperation: BaseOperation<[String: Price]> = ClosureOperation {
            let priceDataList = try priceOperation.extractNoCancellableResultData()

            return priceDataList.reduce(into: [String: Price]()) { accum, priceData in
                guard let asset = priceIdMapping[priceData.identifier] else {
                    return
                }

                let price = Price(
                    lastValue: Decimal(string: priceData.price) ?? 0.0,
                    change: (priceData.dayChange ?? 0.0) / 100.0,
                    currencyId: priceData.currencyId
                )

                accum[asset.identifier] = price
            }
        }

        mappingOperation.addDependency(priceOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [priceOperation])
    }
}
