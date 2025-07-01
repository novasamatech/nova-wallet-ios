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
    private(set) var allAssetSymbols: Set<AssetModel.Symbol> = []
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
        rebuildAssetGroups(using: state)
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

        allAssetSymbols = allChains.values
            .flatMap { $0.chainAssets() }
            .reduce(into: []) { accum, chainAsset in
                accum.insert(chainAsset.asset.symbol)
            }
    }

    private func rebuildChainGroups(using state: AssetListState) {
        var newGroups: [AssetListChainGroupModel] = []
        var newGroupListsByChain: [ChainModel.Id: ListDifferenceCalculator<AssetListAssetModel>] = [:]

        allChains.values.forEach { chain in
            let assets = AssetListModelHelpers.createAssetModels(
                for: chain,
                state: state
            )
            let groups = AssetListModelHelpers.createChainGroupModel(
                from: chain,
                assets: assets
            )

            newGroups.append(groups)

            newGroupListsByChain[chain.chainId] = AssetListModelHelpers.createAssetsDiffCalculator(from: assets)
        }

        chainGroups = AssetListModelHelpers.createGroupsDiffCalculator(
            from: newGroups,
            defaultComparingBy: \.chain
        )

        groupListsByChain = newGroupListsByChain
    }

    private func rebuildAssetGroups(using state: AssetListState) {
        var newGroups: [AssetListAssetGroupModel] = []
        var newGroupListsByChain: [AssetModel.Symbol: ListDifferenceCalculator<AssetListAssetModel>] = [:]

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

        assetsBySymbol(
            using: tokensByChainAsset,
            state: state
        )
        .forEach { symbol, assetListModels in
            let diffCalculator = AssetListModelHelpers.createAssetsDiffCalculator(from: assetListModels)

            newGroupListsByChain[symbol] = diffCalculator

            guard let token = tokensBySymbol[symbol] else {
                return
            }

            let groupModel = AssetListModelHelpers.createAssetGroupModel(
                token: token,
                assets: assetListModels
            )

            newGroups.append(groupModel)
        }

        assetGroups = AssetListModelHelpers.createAssetGroupsDiffCalculator(from: newGroups)
        groupListsByAsset = newGroupListsByChain
    }

    private func assetsBySymbol(
        using tokensByChainAsset: [ChainAssetId: MultichainToken],
        state: AssetListState
    ) -> [AssetModel.Symbol: [AssetListAssetModel]] {
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
    }

    private func processChainChanges(_ changes: [DataProviderChange<ChainModel>]) {
        let state = AssetListState(
            priceResult: priceResult,
            balanceResults: balanceResults,
            allChains: allChains,
            externalBalances: externalBalancesResult
        )

        storeChainChanges(changes)

        rebuildChainGroups(using: state)
        rebuildAssetGroups(using: state)
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

        if dict[key] != nil {
            dict[key]?.apply(changes: changes)
        } else {
            let assetModels = changes.compactMap(\.item)

            dict[key] = AssetListModelHelpers.createAssetsDiffCalculator(from: assetModels)
        }
    }

    private func processBalances(_ results: [ChainAssetId: Result<CalculatedAssetBalance?, Error>]) {
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

        updateGroupsWithBalances(with: results)
    }

    private func updateGroupsWithBalances(with results: [ChainAssetId: Result<CalculatedAssetBalance?, Error>]) {
        var chainListsChanges: [ChainModel.Id: [DataProviderChange<AssetListAssetModel>]] = [:]
        var assetListsChanges: [AssetModel.Symbol: [DataProviderChange<AssetListAssetModel>]] = [:]

        var changedChains: [ChainModel.Id: ChainModel] = [:]

        let tokensByChainAsset = results.keys
            .compactMap {
                allChains[$0.chainId]
            }
            .createMultichainTokensWithValidSymbols(allAssetSymbols)
            .reduce(into: [ChainAssetId: MultichainToken]()) { acc, token in
                token.instances.forEach { acc[$0.chainAssetId] = token }
            }

        let state = AssetListState(
            priceResult: priceResult,
            balanceResults: balanceResults,
            allChains: allChains,
            externalBalances: externalBalancesResult
        )

        for chainAssetId in results.keys {
            guard
                let chainModel = allChains[chainAssetId.chainId],
                let assetModel = chainModel.asset(for: chainAssetId.assetId) else {
                continue
            }

            let assetListAssetModel = AssetListModelHelpers.createAssetModel(
                for: chainModel,
                assetModel: assetModel,
                state: state
            )

            var chainChanges = chainListsChanges[chainAssetId.chainId] ?? []
            chainChanges.append(.update(newItem: assetListAssetModel))
            chainListsChanges[chainAssetId.chainId] = chainChanges

            if let symbol = tokensByChainAsset[assetListAssetModel.chainAssetModel.chainAssetId]?.symbol {
                var assetChanges = assetListsChanges[symbol] ?? []

                let hasModel = groupListsByAsset[symbol]?.allItems.contains(
                    where: { $0.chainAssetModel.chainAssetId == assetListAssetModel.chainAssetModel.chainAssetId }
                ) ?? false

                if hasModel {
                    assetChanges.append(.update(newItem: assetListAssetModel))
                } else {
                    assetChanges.append(.insert(newItem: assetListAssetModel))
                }

                assetListsChanges[symbol] = assetChanges
            }

            changedChains[chainModel.chainId] = chainModel
        }

        applyChainListsChanges(chainListsChanges)
        applyAssetListsChanges(assetListsChanges)

        let chainGroupChanges: [DataProviderChange<AssetListChainGroupModel>] = chainGroupChanges(for: changedChains)

        let assetGroupChanges = assetGroupChanges(
            from: changedChains.flatMap { $0.value.chainAssets() },
            tokensByChainAsset: tokensByChainAsset
        )

        chainGroups.apply(changes: chainGroupChanges)
        assetGroups.apply(changes: assetGroupChanges)
    }

    private func chainGroupChanges(
        for changedChains: [ChainModel.Id: ChainModel]
    ) -> [DataProviderChange<AssetListChainGroupModel>] {
        changedChains.map { keyValue in
            let chainId = keyValue.key
            let chainModel = keyValue.value

            let allItems = groupListsByChain[chainId]?.allItems ?? []

            let groupModel = AssetListModelHelpers.createChainGroupModel(
                from: chainModel,
                assets: allItems
            )

            return .update(newItem: groupModel)
        }
    }

    private func assetGroupChanges(
        from chainAssets: [ChainAsset],
        tokensByChainAsset: [ChainAssetId: MultichainToken]
    ) -> [DataProviderChange<AssetListAssetGroupModel>] {
        chainAssets.compactMap { chainAsset in
            guard
                let token = tokensByChainAsset[chainAsset.chainAssetId],
                let assets = groupListsByAsset[token.symbol]?.allItems
            else {
                return nil
            }

            let group = AssetListModelHelpers.createAssetGroupModel(
                token: token,
                assets: assets
            )

            return .update(newItem: group)
        }
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
