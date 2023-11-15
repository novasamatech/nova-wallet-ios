import Foundation
import RobinHood
import BigInt

enum AssetListModelHelpers {
    static func createNftDiffCalculator() -> ListDifferenceCalculator<NftModel> {
        let sortingBlock: (NftModel, NftModel) -> Bool = { model1, model2 in
            guard let createdAt1 = model1.createdAt, let createdAt2 = model2.createdAt else {
                return true
            }

            return createdAt1.compare(createdAt2) == .orderedDescending
        }

        return ListDifferenceCalculator(initialItems: [], sortBlock: sortingBlock)
    }

    static func createGroupModel(
        from chain: ChainModel,
        assets: [AssetListAssetModel]
    ) -> AssetListGroupModel {
        let amountValue: AmountPair<BigUInt, Decimal> = assets.reduce(.init(amount: 0, value: 0)) { result, asset in
            .init(
                amount: result.amount + (asset.totalAmount ?? 0),
                value: result.value + (asset.totalValue ?? 0)
            )
        }

        return AssetListGroupModel(chain: chain, chainValue: amountValue.value, chainAmount: amountValue.amount)
    }

    static func createGroupsDiffCalculator(
        from groups: [AssetListGroupModel]
    ) -> ListDifferenceCalculator<AssetListGroupModel> {
        let sortingBlock: (AssetListGroupModel, AssetListGroupModel) -> Bool = { model1, model2 in
            if let result = AssetListGroupModelComparator.byValue(model1, model2) {
                return result
            } else if let result = AssetListGroupModelComparator.byTotalAmount(model1, model2) {
                return result
            } else {
                return ChainModelCompator.defaultComparator(chain1: model1.chain, chain2: model2.chain)
            }
        }

        let sortedGroups = groups.sorted(by: sortingBlock)

        return ListDifferenceCalculator(initialItems: sortedGroups, sortBlock: sortingBlock)
    }

    static func createAssetsDiffCalculator(
        from assets: [AssetListAssetModel]
    ) -> ListDifferenceCalculator<AssetListAssetModel> {
        let sortingBlock: (AssetListAssetModel, AssetListAssetModel) -> Bool = { model1, model2 in
            let balance1 = (try? model1.balanceResult?.get()) ?? 0
            let balance2 = (try? model2.balanceResult?.get()) ?? 0

            let assetValue1 = model1.totalValue ?? 0
            let assetValue2 = model2.totalValue ?? 0

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
            } else if model1.assetModel.isUtility != model2.assetModel.isUtility {
                return model1.assetModel.isUtility.intValue > model2.assetModel.isUtility.intValue
            } else {
                return model1.assetModel.symbol.lexicographicallyPrecedes(model2.assetModel.symbol)
            }
        }

        let sortedAssets = assets.sorted(by: sortingBlock)

        return ListDifferenceCalculator(initialItems: sortedAssets, sortBlock: sortingBlock)
    }

    static func createAssetModels(for chainModel: ChainModel, state: AssetListState) -> [AssetListAssetModel] {
        chainModel.assets.map { createAssetModel(for: chainModel, assetModel: $0, state: state) }
    }

    static func createAssetModel(
        for chainModel: ChainModel,
        assetModel: AssetModel,
        state: AssetListState
    ) -> AssetListAssetModel {
        let chainAssetId = ChainAssetId(chainId: chainModel.chainId, assetId: assetModel.assetId)
        let balanceResult = state.balanceResults[chainAssetId]

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

        let externalBalancesContributionResult: Result<BigUInt, Error>? = {
            do {
                let allContributions = try state.externalBalances?.get()

                let contribution = allContributions?[chainAssetId]?.reduce(BigUInt(0)) { accum, contribution in
                    accum + contribution.amount
                }

                return contribution.map { .success($0) }
            } catch {
                return .failure(error)
            }
        }()

        let maybeExternalBalanceContributions: Decimal? = {
            if let contributions = try? externalBalancesContributionResult?.get() {
                return Decimal.fromSubstrateAmount(
                    contributions,
                    precision: Int16(bitPattern: assetModel.precision)
                )
            } else {
                return nil
            }
        }()

        let maybePrice: Decimal? = {
            if let mapping = try? state.priceResult?.get(), let priceData = mapping[chainAssetId] {
                return Decimal(string: priceData.price)
            } else {
                return nil
            }
        }()

        let balanceValue: Decimal? = {
            if let balance = maybeBalance, let price = maybePrice {
                return balance * price
            } else {
                return nil
            }
        }()

        let externalBalanceContributionsValue: Decimal? = {
            if let externalBalanceContributions = maybeExternalBalanceContributions, let price = maybePrice {
                return externalBalanceContributions * price
            } else {
                return nil
            }
        }()

        return AssetListAssetModel(
            assetModel: assetModel,
            balanceResult: balanceResult,
            balanceValue: balanceValue,
            externalBalancesResult: externalBalancesContributionResult,
            externalBalancesValue: externalBalanceContributionsValue
        )
    }
}
