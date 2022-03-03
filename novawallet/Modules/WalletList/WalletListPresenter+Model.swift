import Foundation
import RobinHood

extension WalletListPresenter {
    func createGroupModel(
        from chain: ChainModel,
        assets: [WalletListAssetModel]
    ) -> WalletListGroupModel {
        let value: Decimal = assets.reduce(0) { result, asset in
            result + (asset.assetValue ?? 0)
        }

        return WalletListGroupModel(chain: chain, chainValue: value)
    }

    static func createGroupsDiffCalculator(
        from groups: [WalletListGroupModel]
    ) -> ListDifferenceCalculator<WalletListGroupModel> {
        let sortingBlock: (WalletListGroupModel, WalletListGroupModel) -> Bool = { model1, model2 in
            if model1.chainValue > 0, model2.chainValue > 0 {
                return model1.chainValue > model2.chainValue
            } else if model1.chainValue > 0 {
                return true
            } else if model2.chainValue > 0 {
                return false
            } else {
                return model1.chain.name.lexicographicallyPrecedes(model2.chain.name)
            }
        }

        let sortedGroups = groups.sorted(by: sortingBlock)

        return ListDifferenceCalculator(initialItems: sortedGroups, sortBlock: sortingBlock)
    }

    static func createAssetsDiffCalculator(
        from assets: [WalletListAssetModel]
    ) -> ListDifferenceCalculator<WalletListAssetModel> {
        let sortingBlock: (WalletListAssetModel, WalletListAssetModel) -> Bool = { model1, model2 in
            let balance1 = (try? model1.balanceResult?.get()) ?? 0
            let balance2 = (try? model2.balanceResult?.get()) ?? 0

            let assetValue1 = model1.assetValue ?? 0
            let assetValue2 = model2.assetValue ?? 0

            if assetValue1 > 0, assetValue2 > 0 {
                return assetValue1 > assetValue2
            } else if assetValue1 > 0 {
                return true
            } else if assetValue2 > 0 {
                return false
            } else if balance1 > 0, balance2 > 0 {
                return model1.assetModel.assetId < model2.assetModel.assetId
            } else if balance1 > 0 {
                return true
            } else if balance2 > 0 {
                return false
            } else {
                return model1.assetModel.symbol.lexicographicallyPrecedes(model2.assetModel.symbol)
            }
        }

        let sortedAssets = assets.sorted(by: sortingBlock)

        return ListDifferenceCalculator(initialItems: sortedAssets, sortBlock: sortingBlock)
    }

    func createAssetModels(for chainModel: ChainModel) -> [WalletListAssetModel] {
        chainModel.assets.map { createAssetModel(for: chainModel, assetModel: $0) }
    }

    func createAssetModel(
        for chainModel: ChainModel,
        assetModel: AssetModel
    ) -> WalletListAssetModel {
        let chainAssetId = ChainAssetId(chainId: chainModel.chainId, assetId: assetModel.assetId)
        let balanceResult = balanceResults[chainAssetId]

        let maybeBalance: Decimal? = {
            if let balance = try? balanceResult?.get() {
                return Decimal.fromSubstrateAmount(
                    balance,
                    precision: Int16(bitPattern: assetModel.precision)
                )
            } else {
                return nil
            }
        }()

        let maybePrice: Decimal? = {
            if let mapping = try? priceResult?.get(), let priceData = mapping[chainAssetId] {
                return Decimal(string: priceData.price)
            } else {
                return nil
            }
        }()

        if let balance = maybeBalance, let price = maybePrice {
            let assetValue = balance * price
            return WalletListAssetModel(
                assetModel: assetModel,
                balanceResult: balanceResult,
                assetValue: assetValue
            )
        } else {
            return WalletListAssetModel(
                assetModel: assetModel,
                balanceResult: balanceResult,
                assetValue: nil
            )
        }
    }

    static func createNftDiffCalculator() -> ListDifferenceCalculator<NftModel> {
        let sortingBlock: (NftModel, NftModel) -> Bool = { model1, model2 in
            guard let createdAt1 = model1.createdAt, let createdAt2 = model2.createdAt else {
                return true
            }

            return createdAt1.compare(createdAt2) == .orderedDescending
        }

        return ListDifferenceCalculator(initialItems: [], sortBlock: sortingBlock)
    }
}
