import Foundation
import BigInt
import Operation_iOS

typealias ChainChangeAssetsProcessResult = (
    groupChanges: [DataProviderChange<AssetListAssetGroupModel>],
    listChanges: [AssetModel.Symbol: [DataProviderChange<AssetListAssetModel>]]
)

typealias ChainChangeChainsProcessResult = (
    groupChanges: [DataProviderChange<AssetListChainGroupModel>],
    listChanges: [ChainModel.Id: [DataProviderChange<AssetListAssetModel>]]
)

typealias ChainChangeProcessResult = (
    chainGroupResult: ChainChangeChainsProcessResult,
    assetGroupResult: ChainChangeAssetsProcessResult
)

class AssetListBaseBuilder {
    let workingQueue: DispatchQueue
    let callbackQueue: DispatchQueue
    let rebuildPeriod: TimeInterval

    private(set) var wallet: MetaAccountModel?

    private(set) var chainGroups: ListDifferenceCalculator<AssetListChainGroupModel>
    private(set) var assetGroups: ListDifferenceCalculator<AssetListAssetGroupModel>
    private(set) var groupListsByChain: [ChainModel.Id: ListDifferenceCalculator<AssetListAssetModel>] = [:]
    private(set) var groupListsByAsset: [AssetModel.Symbol: ListDifferenceCalculator<AssetListAssetModel>] = [:]

    private(set) var priceResult: Result<[ChainAssetId: PriceData], Error>?
    private(set) var balanceResults: [ChainAssetId: Result<BigUInt, Error>] = [:]
    private(set) var balances: [ChainAssetId: Result<AssetBalance, Error>] = [:]
    private(set) var allChains: [ChainModel.Id: ChainModel] = [:]
    private(set) var externalBalancesResult: Result<[ChainAssetId: [ExternalAssetBalance]], Error>?

    private(set) var scheduler: Scheduler?

    deinit {
        cancelRebuildModel()
    }

    init(
        workingQueue: DispatchQueue,
        callbackQueue: DispatchQueue,
        rebuildPeriod: TimeInterval
    ) {
        self.workingQueue = workingQueue
        self.callbackQueue = callbackQueue
        self.rebuildPeriod = rebuildPeriod

        chainGroups = AssetListModelHelpers.createGroupsDiffCalculator(
            from: [],
            defaultComparingBy: \.chain
        )
        assetGroups = AssetListModelHelpers.createGroupsDiffCalculator(
            from: [],
            defaultComparingBy: \.chainAsset.chain
        )
    }

    func rebuildModel() {
        fatalError("Must be overriden by subsclass")
    }

    func rebuildModelImmediate() {
        cancelRebuildModel()

        rebuildModel()
    }

    func cancelRebuildModel() {
        scheduler?.cancel()
        scheduler = nil
    }

    func scheduleRebuildModel() {
        guard scheduler == nil else {
            return
        }

        scheduler = Scheduler(with: self, callbackQueue: workingQueue)
        scheduler?.notifyAfter(rebuildPeriod)
    }

    func resetStorages() {
        allChains = [:]
        balanceResults = [:]
        balances = [:]
        chainGroups = AssetListModelHelpers.createGroupsDiffCalculator(
            from: [],
            defaultComparingBy: \.chain
        )
        assetGroups = AssetListModelHelpers.createGroupsDiffCalculator(
            from: [],
            defaultComparingBy: \.chainAsset.chain
        )
        groupListsByChain = [:]
        groupListsByAsset = [:]
        externalBalancesResult = nil
    }

    private func updateAssetModels() {
        let state = AssetListState(
            priceResult: priceResult,
            balanceResults: balanceResults,
            allChains: allChains,
            externalBalances: externalBalancesResult
        )

        updateChainGroups(using: state)
        updateAssetGroups(using: state)
    }

    private func updateChainGroups(using state: AssetListState) {
        for chain in allChains.values {
            let models = AssetListModelHelpers.createAssetModels(for: chain, state: state)

            let changes: [DataProviderChange<AssetListAssetModel>] = models.map { model in
                .update(newItem: model)
            }

            groupListsByChain[chain.chainId]?.apply(changes: changes)

            let groupModel = AssetListModelHelpers.createChainGroupModel(from: chain, assets: models)
            chainGroups.apply(changes: [.update(newItem: groupModel)])
        }
    }

    private func updateAssetGroups(using state: AssetListState) {
        allChains.values
            .flatMap { $0.chainAssets() }
            .reduce(
                into: [AssetModel.Symbol: [AssetListAssetModel]]()
            ) { acc, chainAsset in
                let model = AssetListModelHelpers.createAssetModel(
                    for: chainAsset.chain,
                    assetModel: chainAsset.asset,
                    state: state
                )

                let newValue = (acc[model.chainAssetModel.asset.symbol] ?? []) + [model]
                acc[model.chainAssetModel.asset.symbol] = newValue
            }
            .forEach { symbol, assetListModels in
                guard let groupModel = AssetListModelHelpers.createAssetGroupModel(assets: assetListModels) else {
                    return
                }

                let changes: [DataProviderChange<AssetListAssetModel>] = assetListModels.map { .update(newItem: $0) }

                groupListsByAsset[symbol]?.apply(changes: changes)
                assetGroups.apply(changes: [.update(newItem: groupModel)])
            }
    }

    private func storeChainChanges(_ changes: [DataProviderChange<ChainModel>]) {
        allChains = changes.reduce(into: allChains) { result, change in
            switch change {
            case let .insert(newItem):
                result[newItem.chainId] = newItem
            case let .update(newItem):
                result[newItem.chainId] = newItem
            case let .delete(deletedIdentifier):
                result[deletedIdentifier] = nil
            }
        }
    }

    private func mapChainChanges(
        from changes: [DataProviderChange<ChainModel>],
        using state: AssetListState
    ) -> ChainChangeProcessResult {
        changes
            .reduce(
                into: (
                    chainGroupResult: ChainChangeChainsProcessResult([], [:]),
                    assetGroupResult: ChainChangeAssetsProcessResult([], [:])
                )
            ) { acc, change in
                guard let mappedChange = mapChainChange(change, using: state) else {
                    return
                }

                acc.chainGroupResult.groupChanges.append(contentsOf: mappedChange.chainGroupResult.groupChanges)

                mappedChange.chainGroupResult.listChanges.forEach {
                    let current = acc.chainGroupResult.listChanges[$0.key] ?? []
                    acc.chainGroupResult.listChanges[$0.key] = current + $0.value
                }

                acc.assetGroupResult.groupChanges.append(contentsOf: mappedChange.assetGroupResult.groupChanges)

                mappedChange.assetGroupResult.listChanges.forEach {
                    let current = acc.assetGroupResult.listChanges[$0.key] ?? []
                    acc.assetGroupResult.listChanges[$0.key] = current + $0.value
                }
            }
    }

    private func mapChainChange(
        _ change: DataProviderChange<ChainModel>,
        using state: AssetListState
    ) -> ChainChangeProcessResult? {
        let chainGroupResult: ChainChangeChainsProcessResult
        let assetGroupResult: ChainChangeAssetsProcessResult

        switch change {
        case let .insert(newItem):
            chainGroupResult = AssetListModelHelpers.chainGroupProcessInsertResult(
                on: newItem,
                using: groupListsByChain,
                state: state
            )
            assetGroupResult = AssetListModelHelpers.assetGroupProcessInsertResult(
                on: newItem,
                using: groupListsByAsset,
                state: state
            )
        case let .update(newItem):
            chainGroupResult = AssetListModelHelpers.chainGroupProcessUpdateResult(
                on: newItem,
                using: groupListsByChain,
                state: state
            )
            assetGroupResult = AssetListModelHelpers.assetGroupProcessUpdateResult(
                on: newItem,
                using: groupListsByAsset,
                state: state
            )
        case let .delete(deletedIdentifier):
            guard let chain = allChains[deletedIdentifier] else {
                return nil
            }

            chainGroupResult = AssetListModelHelpers.chainGroupProcessDeleteResult(
                chainId: deletedIdentifier,
                chainGroup: chainGroups,
                groupListsByChain: groupListsByChain
            )
            assetGroupResult = AssetListModelHelpers.assetGroupProcessDeleteResult(
                chain: chain,
                assetGroup: assetGroups,
                groupListsByAsset: groupListsByAsset
            )
        }

        return (chainGroupResult, assetGroupResult)
    }

    private func processChainChanges(_ changes: [DataProviderChange<ChainModel>]) {
        let state = AssetListState(
            priceResult: priceResult,
            balanceResults: balanceResults,
            allChains: allChains,
            externalBalances: externalBalancesResult
        )

        let (chainGroupsChanges, assetGroupsChanges) = mapChainChanges(
            from: changes,
            using: state
        )

        chainGroups.apply(changes: chainGroupsChanges.groupChanges)
        assetGroups.apply(changes: assetGroupsChanges.groupChanges)

        applyChainListsChanges(chainGroupsChanges.listChanges)
        applyAssetListsChanges(assetGroupsChanges.listChanges)

        storeChainChanges(changes)
    }

    private func applyChainListsChanges(_ changes: [ChainModel.Id: [DataProviderChange<AssetListAssetModel>]]) {
        changes.forEach {
            applyListChanges(
                for: &groupListsByChain,
                key: $0.key,
                changes: $0.value
            )
        }
    }

    private func applyAssetListsChanges(_ changes: [AssetModel.Symbol: [DataProviderChange<AssetListAssetModel>]]) {
        changes.forEach {
            applyListChanges(
                for: &groupListsByAsset,
                key: $0.key,
                changes: $0.value
            )
        }
    }

    private func applyListChanges(
        for dict: inout [String: ListDifferenceCalculator<AssetListAssetModel>],
        key: String,
        changes: [DataProviderChange<AssetListAssetModel>]
    ) {
        guard !changes.isEmpty else { return }

        var mutChanges = changes

        if dict[key] != nil {
            dict[key]?.apply(changes: changes)
        } else {
            let assetModel = changes
                .compactMap(\.item)
                .first

            guard let assetModel else { return }

            dict[key] = AssetListModelHelpers.createAssetsDiffCalculator(from: [assetModel])

            applyListChanges(
                for: &dict,
                key: key,
                changes: Array(changes.dropFirst())
            )
        }
    }

    private func processBalances(_ results: [ChainAssetId: Result<CalculatedAssetBalance?, Error>]) {
        var chainListsChanges: [ChainModel.Id: [DataProviderChange<AssetListAssetModel>]] = [:]
        var assetListsChanges: [AssetModel.Symbol: [DataProviderChange<AssetListAssetModel>]] = [:]

        var changedChainGroups: [ChainModel.Id: ChainModel] = [:]

        for (chainAssetId, result) in results {
            switch result {
            case let .success(maybeAmount):
                if let amount = maybeAmount {
                    balanceResults[chainAssetId] = .success(amount.total)
                    balances[chainAssetId] = amount.balance.map { .success($0) }
                } else if balanceResults[chainAssetId] == nil {
                    balanceResults[chainAssetId] = .success(0)
                }
            case let .failure(error):
                balanceResults[chainAssetId] = .failure(error)
                balances[chainAssetId] = .failure(error)
            }
        }

        for chainAssetId in results.keys {
            guard
                let chainModel = allChains[chainAssetId.chainId],
                let assetModel = chainModel.assets.first(
                    where: { $0.assetId == chainAssetId.assetId }
                ) else {
                continue
            }

            let state = AssetListState(
                priceResult: priceResult,
                balanceResults: balanceResults,
                allChains: allChains,
                externalBalances: externalBalancesResult
            )

            let assetListModel = AssetListModelHelpers.createAssetModel(
                for: chainModel,
                assetModel: assetModel,
                state: state
            )

            var chainChanges = chainListsChanges[chainAssetId.chainId] ?? []
            chainChanges.append(.update(newItem: assetListModel))

            chainListsChanges[chainAssetId.chainId] = chainChanges

            changedChainGroups[chainModel.chainId] = chainModel
        }

        applyChainListsChanges(chainListsChanges)
        applyAssetListsChanges(assetListsChanges)

        let chainGroupChanges: [DataProviderChange<AssetListChainGroupModel>] = changedChainGroups.map { keyValue in
            let chainId = keyValue.key
            let chainModel = keyValue.value

            let allItems = groupListsByChain[chainId]?.allItems ?? []

            let groupModel = AssetListModelHelpers.createChainGroupModel(
                from: chainModel,
                assets: allItems
            )

            return .update(newItem: groupModel)
        }

        let assetGroupChanges: [DataProviderChange<AssetListAssetGroupModel>] = changedChainGroups
            .values
            .flatMap { $0.chainAssets() }
            .compactMap { chainAsset in
                guard
                    let assets = groupListsByAsset[chainAsset.asset.symbol]?.allItems,
                    let group = AssetListModelHelpers.createAssetGroupModel(assets: assets)
                else {
                    return nil
                }

                return .update(newItem: group)
            }

        chainGroups.apply(changes: chainGroupChanges)
        assetGroups.apply(changes: assetGroupChanges)
    }

    private func processRemovedPriceChainAssets(_ chainAssetIds: Set<ChainAssetId>) -> Bool {
        let currentPrices: [ChainAssetId: PriceData] = (try? priceResult?.get()) ?? [:]

        let removedChainAssetIds = currentPrices.keys.filter { !chainAssetIds.contains($0) }

        guard !removedChainAssetIds.isEmpty else {
            return false
        }

        let newPrices = currentPrices.filter { !removedChainAssetIds.contains($0.key) }

        priceResult = .success(newPrices)

        updateAssetModels()

        return true
    }

    private func processPriceChanges(_ changes: [ChainAssetId: DataProviderChange<PriceData>]) {
        var currentPrices: [ChainAssetId: PriceData] = (try? priceResult?.get()) ?? [:]

        currentPrices = changes.reduce(into: currentPrices) { accum, keyValue in
            switch keyValue.value {
            case let .insert(newItem), let .update(newItem):
                accum[keyValue.key] = newItem
            case .delete:
                accum[keyValue.key] = nil
            }
        }

        priceResult = .success(currentPrices)

        updateAssetModels()
    }

    private func processExternalBalances(_ result: Result<[ChainAssetId: [ExternalAssetBalance]], Error>) {
        externalBalancesResult = result
        updateAssetModels()
    }
}

extension AssetListBaseBuilder: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        rebuildModelImmediate()
    }
}

extension AssetListBaseBuilder {
    func applyChainModelChanges(_ changes: [DataProviderChange<ChainModel>]) {
        workingQueue.async { [weak self] in
            self?.processChainChanges(changes)

            self?.scheduleRebuildModel()
        }
    }

    func applyBalances(_ results: [ChainAssetId: Result<CalculatedAssetBalance?, Error>]) {
        workingQueue.async { [weak self] in
            self?.processBalances(results)

            self?.scheduleRebuildModel()
        }
    }

    func applyExternalBalances(_ result: Result<[ChainAssetId: [ExternalAssetBalance]], Error>) {
        workingQueue.async { [weak self] in
            self?.processExternalBalances(result)

            self?.scheduleRebuildModel()
        }
    }

    func applyRemovedPriceChainAssets(_ chainAssetIds: Set<ChainAssetId>) {
        workingQueue.async { [weak self] in
            guard let self = self else {
                return
            }

            if self.processRemovedPriceChainAssets(chainAssetIds) {
                self.scheduleRebuildModel()
            }
        }
    }

    func applyPriceChanges(_ priceChanges: [ChainAssetId: DataProviderChange<PriceData>]) {
        workingQueue.async { [weak self] in
            self?.processPriceChanges(priceChanges)

            self?.scheduleRebuildModel()
        }
    }

    func applyPrice(error: Error) {
        workingQueue.async { [weak self] in
            if let self = self, self.priceResult == nil {
                self.priceResult = .failure(error)

                self.updateAssetModels()
                self.scheduleRebuildModel()
            }
        }
    }

    func applyWallet(_ wallet: MetaAccountModel) {
        workingQueue.async { [weak self] in
            self?.wallet = wallet

            self?.resetStorages()

            self?.rebuildModelImmediate()
        }
    }
}
