import Foundation
import Operation_iOS
import BigInt

enum AssetListModelHelpers {
    static func createNftDiffCalculator() -> ListDifferenceCalculator<NftModel> {
        let sortingBlock = AssetListModelHelpers.nftSortingBlock

        return ListDifferenceCalculator(initialItems: [], sortBlock: sortingBlock)
    }

    static func createAssetGroupModel(
        token: MultichainToken,
        assets: [AssetListAssetModel]
    ) -> AssetListAssetGroupModel {
        let amountValue: AmountPair<Decimal, Decimal> = assets.reduce(.init(amount: 0, value: 0)) { result, asset in
            .init(
                amount: result.amount + asset.totalAmount.decimalOrZero(
                    precision: asset.chainAssetModel.asset.precision
                ),
                value: result.value + (asset.totalValue ?? 0)
            )
        }

        return AssetListAssetGroupModel(
            multichainToken: token,
            value: amountValue.value,
            amount: amountValue.amount
        )
    }

    static func createChainGroupModel(
        from chain: ChainModel,
        assets: [AssetListAssetModel]
    ) -> AssetListChainGroupModel {
        let amountValue: AmountPair<Decimal, Decimal> = assets.reduce(.init(amount: 0, value: 0)) { result, asset in
            .init(
                amount: result.amount + asset.totalAmount.decimalOrZero(
                    precision: asset.chainAssetModel.asset.precision
                ),
                value: result.value + (asset.totalValue ?? 0)
            )
        }

        return AssetListChainGroupModel(
            chain: chain,
            value: amountValue.value,
            amount: amountValue.amount
        )
    }

    static func createAssetGroupsDiffCalculator(
        from groups: [AssetListAssetGroupModel]
    ) -> ListDifferenceCalculator<AssetListAssetGroupModel> {
        let sortingBlock = AssetListModelHelpers.assetListAssetGroupSortingBlock

        let sortedGroups = groups.sorted(by: sortingBlock)

        return ListDifferenceCalculator(
            initialItems: sortedGroups,
            sortBlock: sortingBlock
        )
    }

    static func createGroupsDiffCalculator<T: GroupAmountContainable>(
        from groups: [T],
        defaultComparingBy: KeyPath<T, ChainModel>
    ) -> ListDifferenceCalculator<T> {
        let sortingBlock: (T, T) -> Bool = { lhs, rhs in
            if let result = AssetListGroupModelComparator.by(\.value, lhs, rhs) {
                result
            } else if let result = AssetListGroupModelComparator.by(\.amount, lhs, rhs) {
                result
            } else {
                ChainModelCompator.defaultComparator(
                    chain1: lhs[keyPath: defaultComparingBy],
                    chain2: rhs[keyPath: defaultComparingBy]
                )
            }
        }

        let sortedGroups = groups.sorted(by: sortingBlock)

        return ListDifferenceCalculator(
            initialItems: sortedGroups,
            sortBlock: sortingBlock
        )
    }

    static func createAssetsDiffCalculator(
        from assets: [AssetListAssetModel]
    ) -> ListDifferenceCalculator<AssetListAssetModel> {
        let sortingBlock = AssetListModelHelpers.assetSortByUtilityThenPriority

        let sortedAssets = assets.sorted(by: sortingBlock)

        return ListDifferenceCalculator(
            initialItems: sortedAssets,
            sortBlock: sortingBlock
        )
    }

    static func createChainAssetsDiffCalculator(
        from assets: [AssetListAssetModel]
    ) -> ListDifferenceCalculator<AssetListAssetModel> {
        let sortingBlock = AssetListModelHelpers.chainAssetSortByUtilityThenPriority

        let sortedAssets = assets.sorted(by: sortingBlock)

        return ListDifferenceCalculator(
            initialItems: sortedAssets,
            sortBlock: sortingBlock
        )
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

        let chainAsset = ChainAsset(chain: chainModel, asset: assetModel)

        return AssetListAssetModel(
            chainAssetModel: chainAsset,
            balanceResult: balanceResult,
            balanceValue: balanceValue,
            externalBalancesResult: externalBalancesContributionResult,
            externalBalancesValue: externalBalanceContributionsValue
        )
    }
}
