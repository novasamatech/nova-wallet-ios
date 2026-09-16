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
        groupSymbol: String,
        sharesChain: Bool,
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
                asset.totalAmountDecimal ?? .zero,
                priceData: priceData
            ).value(for: locale)
        } else {
            ""
        }

        let chainAssetViewModel = chainAssetViewModelFactory.createViewModel(
            from: asset.chainAssetModel
        )

        return AssetOperationNetworkViewModel(
            chainAsset: chainAssetViewModel,
            variantSymbol: MultichainToken.variantSymbol(
                of: asset.chainAssetModel.asset.symbol,
                inGroupWith: groupSymbol,
                sharingChainWithSiblings: sharesChain
            ),
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
        groupSymbol: String,
        priceData: [ChainAssetId: PriceData],
        locale: Locale
    ) -> [AssetOperationNetworkViewModel] {
        let assetsPerChain = assets.reduce(into: [ChainModel.Id: Int]()) { counts, asset in
            counts[asset.chainAssetModel.chainAssetId.chainId, default: 0] += 1
        }

        return assets.compactMap { asset in
            createViewModel(
                from: asset,
                groupSymbol: groupSymbol,
                sharesChain: assetsPerChain[asset.chainAssetModel.chainAssetId.chainId, default: 0] > 1,
                using: priceData[asset.chainAssetModel.chainAssetId],
                locale: locale
            )
        }
    }
}
