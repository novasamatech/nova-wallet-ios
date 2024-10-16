import Foundation
import Operation_iOS
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

    static func createAssetGroupModel(
        assets: [AssetListAssetModel]
    ) -> AssetListAssetGroupModel? {
        let amountValue: AmountPair<Decimal, Decimal> = assets.reduce(.init(amount: 0, value: 0)) { result, asset in
            .init(
                amount: result.amount + asset.totalAmount.decimalOrZero(
                    precision: asset.chainAssetModel.asset.precision
                ),
                value: result.value + (asset.totalValue ?? 0)
            )
        }

        guard let chainAsset = assets
            .first(where: { $0.chainAssetModel.isUtilityAsset })?
            .chainAssetModel
        else {
            return nil
        }

        return AssetListAssetGroupModel(
            chainAsset: chainAsset,
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
        let sortingBlock: (AssetListAssetModel, AssetListAssetModel) -> Bool = { model1, model2 in
            let balance1 = model1.totalAmountDecimal ?? 0
            let balance2 = model2.totalAmountDecimal ?? 0

            let assetValue1 = model1.totalValue ?? 0
            let assetValue2 = model2.totalValue ?? 0

            if assetValue1 > 0, assetValue2 > 0 {
                return assetValue1 > assetValue2
            } else if assetValue1 > 0 {
                return true
            } else if assetValue2 > 0 {
                return false
            } else if balance1 > 0, balance2 > 0 {
                return balance1 > balance2
            } else if balance1 > 0 {
                return true
            } else if balance2 > 0 {
                return false
            } else if model1.chainAssetModel.asset.isUtility != model2.chainAssetModel.asset.isUtility {
                return model1.chainAssetModel.asset.isUtility.intValue > model2.chainAssetModel.asset.isUtility.intValue
            } else {
                return model1.chainAssetModel.asset.symbol.lexicographicallyPrecedes(
                    model2.chainAssetModel.asset.symbol
                )
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

        let chainAsset = ChainAsset(chain: chainModel, asset: assetModel)

        return AssetListAssetModel(
            chainAssetModel: chainAsset,
            balanceResult: balanceResult,
            balanceValue: balanceValue,
            externalBalancesResult: externalBalancesContributionResult,
            externalBalancesValue: externalBalanceContributionsValue
        )
    }

    // MARK: Changes mapping

    private static func chainGroupChanges(
        on newChain: ChainModel,
        using groupListsByChain: [ChainModel.Id: ListDifferenceCalculator<AssetListAssetModel>],
        state: AssetListState
    ) -> (
        groups: [AssetListChainGroupModel],
        listChanges: [ChainModel.Id: [DataProviderChange<AssetListAssetModel>]]
    ) {
        let assets = AssetListModelHelpers.createAssetModels(
            for: newChain,
            state: state
        )
        let listChanges = createChainListChanges(
            for: newChain,
            assets: assets,
            using: groupListsByChain
        )

        let groupModel = AssetListModelHelpers.createChainGroupModel(
            from: newChain,
            assets: assets
        )

        return (
            [groupModel],
            listChanges
        )
    }

    private static func assetGroupChanges(
        on newChain: ChainModel,
        using groupListsByAsset: [AssetModel.Symbol: ListDifferenceCalculator<AssetListAssetModel>],
        state: AssetListState
    ) -> (
        groups: [AssetListAssetGroupModel],
        listChanges: [AssetModel.Symbol: [DataProviderChange<AssetListAssetModel>]]
    ) {
        let newAssets = AssetListModelHelpers.createAssetModels(
            for: newChain,
            state: state
        )

        let listChanges = createAssetListChanges(
            for: newAssets,
            using: groupListsByAsset
        )

        let groupModel = AssetListModelHelpers.createAssetGroupModel(
            assets: newAssets
        )

        let arr: [AssetListAssetGroupModel] = if let groupModel {
            [groupModel]
        } else {
            []
        }

        return (arr, listChanges)
    }

    static func chainGroupProcessInsertResult(
        on insertedChain: ChainModel,
        using groupListsByChain: [ChainModel.Id: ListDifferenceCalculator<AssetListAssetModel>],
        state: AssetListState
    ) -> ChainChangeChainsProcessResult {
        let changes = chainGroupChanges(
            on: insertedChain,
            using: groupListsByChain,
            state: state
        )

        return ChainChangeChainsProcessResult(
            groupChanges: changes.groups.map { .insert(newItem: $0) },
            listChanges: changes.listChanges
        )
    }

    static func chainGroupProcessUpdateResult(
        on insertedChain: ChainModel,
        using groupListsByChain: [ChainModel.Id: ListDifferenceCalculator<AssetListAssetModel>],
        state: AssetListState
    ) -> ChainChangeChainsProcessResult {
        let changes = chainGroupChanges(
            on: insertedChain,
            using: groupListsByChain,
            state: state
        )

        return ChainChangeChainsProcessResult(
            groupChanges: changes.groups.map { .update(newItem: $0) },
            listChanges: changes.listChanges
        )
    }

    static func assetGroupProcessInsertResult(
        on insertedChain: ChainModel,
        using groupListsByAsset: [AssetModel.Symbol: ListDifferenceCalculator<AssetListAssetModel>],
        state: AssetListState
    ) -> ChainChangeAssetsProcessResult {
        let changes = assetGroupChanges(
            on: insertedChain,
            using: groupListsByAsset,
            state: state
        )

        return ChainChangeAssetsProcessResult(
            groupChanges: changes.groups.map { .insert(newItem: $0) },
            listChanges: changes.listChanges
        )
    }

    static func assetGroupProcessUpdateResult(
        on insertedChain: ChainModel,
        using groupListsByAsset: [AssetModel.Symbol: ListDifferenceCalculator<AssetListAssetModel>],
        state: AssetListState
    ) -> ChainChangeAssetsProcessResult {
        let changes = assetGroupChanges(
            on: insertedChain,
            using: groupListsByAsset,
            state: state
        )

        return ChainChangeAssetsProcessResult(
            groupChanges: changes.groups.map { .update(newItem: $0) },
            listChanges: changes.listChanges
        )
    }

    static func assetGroupProcessDeleteResult(
        chain: ChainModel,
        assetGroup: ListDifferenceCalculator<AssetListAssetGroupModel>,
        groupListsByAsset: [AssetModel.Symbol: ListDifferenceCalculator<AssetListAssetModel>]
    ) -> ChainChangeAssetsProcessResult {
        let groupChanges: [DataProviderChange<AssetListAssetGroupModel>] = assetGroup.allItems
            .filter { $0.chainAsset.chain.chainId == chain.chainId }
            .map { .delete(deletedIdentifier: $0.identifier) }

        let listChanges: [AssetModel.Symbol: [DataProviderChange<AssetListAssetModel>]] = chain.chainAssets()
            .compactMap { groupListsByAsset[$0.asset.symbol]?.allItems }
            .flatMap { $0 }
            .filter { $0.chainAssetModel.identifier == $0.identifier }
            .reduce(into: [:]) { acc, model in
                var changes = acc[model.chainAssetModel.asset.symbol] ?? []
                changes.append(.delete(deletedIdentifier: model.identifier))

                acc[model.chainAssetModel.asset.symbol] = changes
            }

        return ChainChangeAssetsProcessResult(
            groupChanges: groupChanges,
            listChanges: listChanges
        )
    }

    static func chainGroupProcessDeleteResult(
        chainId: ChainModel.Id,
        chainGroup _: ListDifferenceCalculator<AssetListChainGroupModel>,
        groupListsByChain _: [ChainModel.Id: ListDifferenceCalculator<AssetListAssetModel>]
    ) -> ChainChangeChainsProcessResult {
        ChainChangeChainsProcessResult(
            groupChanges: [.delete(deletedIdentifier: chainId)],
            listChanges: [chainId: [.delete(deletedIdentifier: chainId)]]
        )
    }

    static func createAssetListChanges(
        for newAssets: [AssetListAssetModel],
        using groupListsByAsset: [AssetModel.Symbol: ListDifferenceCalculator<AssetListAssetModel>]
    ) -> [AssetModel.Symbol: [DataProviderChange<AssetListAssetModel>]] {
        newAssets
            .reduce(into: [:]) { acc, asset in
                guard let oldList = groupListsByAsset[asset.chainAssetModel.asset.symbol] else {
                    return
                }

                let newChanges = createChanges(for: oldList, asset: asset)

                var currentChanges = acc[asset.chainAssetModel.asset.symbol] ?? []

                acc[asset.chainAssetModel.asset.symbol] = currentChanges + newChanges
            }
    }

    static func createChainListChanges(
        for newChain: ChainModel,
        assets: [AssetListAssetModel],
        using groupListsByChain: [ChainModel.Id: ListDifferenceCalculator<AssetListAssetModel>]
    ) -> [ChainModel.Id: [DataProviderChange<AssetListAssetModel>]] {
        assets
            .reduce(into: [:]) { acc, asset in
                guard let oldList = groupListsByChain[newChain.chainId] else {
                    var currentChanges = acc[newChain.chainId] ?? []
                    currentChanges.append(.insert(newItem: asset))

                    acc[newChain.chainId] = currentChanges

                    return
                }

                let newChanges = createChanges(for: oldList, asset: asset)

                var currentChanges = acc[newChain.chainId] ?? []

                acc[newChain.chainId] = currentChanges + newChanges
            }
    }

    private static func createChanges(
        for list: ListDifferenceCalculator<AssetListAssetModel>,
        asset: AssetListAssetModel
    ) -> [DataProviderChange<AssetListAssetModel>] {
        if list.allItems.contains(
            where: { $0.identifier == asset.identifier }
        ) {
            [.update(newItem: asset)]
        } else {
            [.insert(newItem: asset)]
        }
    }
}
