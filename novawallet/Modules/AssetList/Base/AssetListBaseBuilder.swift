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

// swiftlint:disable:next type_body_length
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
        assetGroups = AssetListModelHelpers.createAssetGroupsDiffCalculator(from: [])
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
        assetGroups = AssetListModelHelpers.createAssetGroupsDiffCalculator(from: [])
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
        var tokensBySymbol: [AssetModel.Symbol: MultichainToken] = [:]
        var tokensByChainAsset: [ChainAssetId: MultichainToken] = [:]

        Array(allChains.values)
            .createMultichainTokens()
            .forEach { token in
                token.instances.forEach {
                    tokensByChainAsset[$0.chainAssetId] = token
                }

                tokensBySymbol[token.symbol] = token
            }

        allChains.values
            .flatMap { $0.chainAssets() }
            .reduce(
                into: [AssetModel.Symbol: [AssetListAssetModel]]()
            ) { acc, chainAsset in
                guard let symbol = tokensByChainAsset[chainAsset.chainAssetId]?.symbol else {
                    return
                }

                let model = AssetListModelHelpers.createAssetModel(
                    for: chainAsset.chain,
                    assetModel: chainAsset.asset,
                    state: state
                )

                let newValue = (acc[symbol] ?? []) + [model]
                acc[symbol] = newValue
            }
            .forEach { symbol, assetListModels in
                let changes: [DataProviderChange<AssetListAssetModel>] = assetListModels.map { .update(newItem: $0) }

                groupListsByAsset[symbol]?.apply(changes: changes)

                guard
                    let assets = groupListsByAsset[symbol],
                    let token = tokensBySymbol[symbol]
                else {
                    return
                }

                let groupModel = AssetListModelHelpers.createAssetGroupModel(
                    token: token,
                    assets: assets.allItems
                )

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

    func mapToAssetsChanges(
        from chainChanges: [DataProviderChange<ChainModel>],
        using state: AssetListState
    ) -> ChainChangeAssetsProcessResult {
        let chains = chainChanges.compactMap(\.item)

        let chainAssets: [ChainAssetId: ChainAsset] = chains.reduce(into: [:]) { acc, chain in
            chain.chainAssets().forEach { acc[$0.chainAssetId] = $0 }
        }

        let multichainTokensMapping: [AssetModel.Symbol: MultichainToken] = chains
            .createMultichainTokens()
            .reduce(into: [:]) { $0[$1.symbol] = $1 }

        let newAssets = multichainTokensMapping
            .map { _, multichainToken in
                let newAssets = multichainToken.instances
                    .compactMap {
                        if let chainAsset = chainAssets[$0.chainAssetId] {
                            return AssetListModelHelpers.createAssetModel(
                                for: chainAsset.chain,
                                assetModel: chainAsset.asset,
                                state: state
                            )
                        } else {
                            return nil
                        }
                    }

                return (multichainToken, newAssets)
            }

        let groupChanges = assetGroupsChanges(for: newAssets)
        let listChanges = assetListChanges(for: newAssets)

        return ChainChangeAssetsProcessResult(
            groupChanges: groupChanges,
            listChanges: listChanges
        )
    }

    func assetGroupsChanges(
        for tokenAssets: [(MultichainToken, [AssetListAssetModel])]
    ) -> [DataProviderChange<AssetListAssetGroupModel>] {
        let newGroups = tokenAssets.map { token, assets in
            AssetListModelHelpers.createAssetGroupModel(
                token: token,
                assets: assets
            )
        }

        return newGroups.map {
            if groupListsByAsset[$0.multichainToken.symbol] != nil {
                .update(newItem: $0)
            } else {
                .insert(newItem: $0)
            }
        }
    }

    func assetListChanges(
        for tokenAssets: [(MultichainToken, [AssetListAssetModel])]
    ) -> [AssetModel.Symbol: [DataProviderChange<AssetListAssetModel>]] {
        tokenAssets
            .reduce(into: [:]) { acc, tokenAssets in
                if let currentAssetList = groupListsByAsset[tokenAssets.0.symbol]?.allItems {
                    tokenAssets.1.forEach { asset in
                        if currentAssetList.contains(
                            where: { $0.chainAssetModel.chainAssetId == asset.chainAssetModel.chainAssetId }
                        ) {
                            acc[tokenAssets.0.symbol]?.append(.update(newItem: asset))
                        } else {
                            acc[tokenAssets.0.symbol]?.append(.insert(newItem: asset))
                        }
                    }
                } else {
                    acc[tokenAssets.0.symbol] = tokenAssets.1.map { .insert(newItem: $0) }
                }
            }
    }

    private func mapChainChanges(
        from changes: [DataProviderChange<ChainModel>],
        using state: AssetListState
    ) -> ChainChangeProcessResult {
        let assetsChanges = mapToAssetsChanges(
            from: changes,
            using: state
        )

        let chainsChanges = mapToChainsChanges(
            from: changes,
            using: state
        )

        return ChainChangeProcessResult(
            chainGroupResult: chainsChanges,
            assetGroupResult: assetsChanges
        )
    }

    private func mapToChainsChanges(
        from changes: [DataProviderChange<ChainModel>],
        using state: AssetListState
    ) -> ChainChangeChainsProcessResult {
        changes
            .reduce(
                into: ChainChangeChainsProcessResult([], [:])
            ) { acc, change in
                guard let mappedChange = mapChainChange(change, using: state) else {
                    return
                }

                acc.groupChanges.append(contentsOf: mappedChange.groupChanges)

                mappedChange.listChanges.forEach {
                    let current = acc.listChanges[$0.key] ?? []
                    acc.listChanges[$0.key] = current + $0.value
                }
            }
    }

    private func mapChainChange(
        _ change: DataProviderChange<ChainModel>,
        using state: AssetListState
    ) -> ChainChangeChainsProcessResult? {
        let chainGroupResult: ChainChangeChainsProcessResult

        switch change {
        case let .insert(newItem):
            chainGroupResult = AssetListModelHelpers.chainGroupProcessInsertResult(
                on: newItem,
                using: groupListsByChain,
                state: state
            )
        case let .update(newItem):
            chainGroupResult = AssetListModelHelpers.chainGroupProcessUpdateResult(
                on: newItem,
                using: groupListsByChain,
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
        }

        return chainGroupResult
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
            let assetModel = mutChanges
                .compactMap(\.item)
                .first

            guard let assetModel else { return }

            mutChanges = mutChanges.filter {
                $0.item?.chainAssetModel.chainAssetId != assetModel.chainAssetModel.chainAssetId
            }

            dict[key] = AssetListModelHelpers.createAssetsDiffCalculator(from: [assetModel])

            applyListChanges(
                for: &dict,
                key: key,
                changes: Array(mutChanges)
            )
        }
    }

    private func processBalances(_ results: [ChainAssetId: Result<CalculatedAssetBalance?, Error>]) {
        var chainListsChanges: [ChainModel.Id: [DataProviderChange<AssetListAssetModel>]] = [:]
        var assetListsChanges: [AssetModel.Symbol: [DataProviderChange<AssetListAssetModel>]] = [:]

        var changedChainGroups: [ChainModel.Id: ChainModel] = [:]

        let tokensByChainAsset = results.keys
            .compactMap {
                allChains[$0.chainId]
            }
            .createMultichainTokens()
            .reduce(into: [ChainAssetId: MultichainToken]()) { acc, token in
                token.instances.forEach { acc[$0.chainAssetId] = token }
            }

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

            let assetListAssetModel = AssetListModelHelpers.createAssetModel(
                for: chainModel,
                assetModel: assetModel,
                state: state
            )

            var chainChanges = chainListsChanges[chainAssetId.chainId] ?? []
            chainChanges.append(.update(newItem: assetListAssetModel))

            if let symbol = tokensByChainAsset[assetListAssetModel.chainAssetModel.chainAssetId]?.symbol {
                var assetChanges = assetListsChanges[symbol] ?? []
                if groupListsByAsset[symbol]?.allItems.contains(
                    where: { $0.chainAssetModel.chainAssetId == assetListAssetModel.chainAssetModel.chainAssetId }
                ) ?? false {
                    assetChanges.append(.update(newItem: assetListAssetModel))
                } else {
                    assetChanges.append(.insert(newItem: assetListAssetModel))
                }

                assetListsChanges[assetModel.symbol] = assetChanges
            }

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
                    let token = tokensByChainAsset[chainAsset.chainAssetId]
                else {
                    return nil
                }

                let group = AssetListModelHelpers.createAssetGroupModel(
                    token: token,
                    assets: assets
                )

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
