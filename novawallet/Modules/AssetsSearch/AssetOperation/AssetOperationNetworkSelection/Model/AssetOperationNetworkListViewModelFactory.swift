import Foundation

class AssetOperationNetworkListViewModelFactory {
    let chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    let assetFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(
        chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        assetFormatterFactory: AssetBalanceFormatterFactoryProtocol
    ) {
        self.chainAssetViewModelFactory = chainAssetViewModelFactory
        self.priceAssetInfoFactory = priceAssetInfoFactory
        self.assetFormatterFactory = assetFormatterFactory
    }
}

private extension AssetOperationNetworkListViewModelFactory {
    func createViewModel(
        from asset: AssetListAssetModel,
        using priceData: PriceData?,
        locale: Locale
    ) -> AssetOperationNetworkViewModel {
        let balanceFactory = balanceViewModelFactory(assetInfo: asset.chainAssetModel.assetDisplayInfo)

        let balanceFormatter = assetFormatterFactory.createDisplayFormatter(for: asset.chainAssetModel.assetDisplayInfo)

        let balanceAmountString = balanceFormatter.value(for: locale).stringFromDecimal(
            asset.totalAmountDecimal ?? .zero
        ) ?? ""

        let balanceValueString = if let priceData {
            balanceFactory.priceFromAmount(
                asset.totalValue ?? .zero,
                priceData: priceData
            ).value(for: locale)
        } else {
            ""
        }

        let chainAssetViewModel = chainAssetViewModelFactory.createIdentifiableViewModel(
            from: asset.chainAssetModel
        )

        return AssetOperationNetworkViewModel(
            chainAsset: chainAssetViewModel,
            amount: balanceAmountString,
            value: balanceValueString
        )
    }

    func balanceViewModelFactory(assetInfo: AssetBalanceDisplayInfo) -> BalanceViewModelFactoryProtocol {
        BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
    }
}

extension AssetOperationNetworkListViewModelFactory {
    func createViewModels(
        assets: [AssetListAssetModel],
        priceData: [ChainAssetId: PriceData],
        locale: Locale
    ) -> [AssetOperationNetworkViewModel] {
        assets.compactMap { asset in
            createViewModel(
                from: asset,
                using: priceData[asset.chainAssetModel.chainAssetId],
                locale: locale
            )
        }
    }
}
