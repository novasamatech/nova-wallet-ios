import Foundation
import RobinHood
import BigInt

class AssetListBasePresenter: AssetListBaseInteractorOutputProtocol {
    private(set) var groups: ListDifferenceCalculator<AssetListGroupModel>
    private(set) var groupLists: [ChainModel.Id: ListDifferenceCalculator<AssetListAssetModel>] = [:]

    private(set) var priceResult: Result<[ChainAssetId: PriceData], Error>?
    private(set) var balanceResults: [ChainAssetId: Result<BigUInt, Error>] = [:]
    private(set) var balances: [ChainAssetId: Result<AssetBalance, Error>] = [:]
    private(set) var allChains: [ChainModel.Id: ChainModel] = [:]
    private(set) var allLocks: [AssetLock] = []

    init() {
        groups = Self.createGroupsDiffCalculator(from: [])
    }

    func resetStorages() {
        allChains = [:]
        balanceResults = [:]
        balances = [:]
        groups = Self.createGroupsDiffCalculator(from: [])
        groupLists = [:]
        allLocks = []
    }

    func storeChainChanges(_ changes: [DataProviderChange<ChainModel>]) {
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

    func storeGroups(
        _ groups: ListDifferenceCalculator<AssetListGroupModel>,
        groupLists: [ChainModel.Id: ListDifferenceCalculator<AssetListAssetModel>]
    ) {
        self.groups = groups
        self.groupLists = groupLists
    }

    func applyInitState(_ initState: AssetListInitState) {
        allChains = initState.allChains
        balanceResults = initState.balanceResults
        priceResult = initState.priceResult
    }

    func createAssetAccountInfo(
        from asset: AssetListAssetModel,
        chain: ChainModel,
        maybePrices: [ChainAssetId: PriceData]?
    ) -> AssetListAssetAccountInfo {
        let assetModel = asset.assetModel
        let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: assetModel.assetId)

        let assetInfo = assetModel.displayInfo(with: chain.icon)

        let priceData: PriceData?

        if let prices = maybePrices {
            priceData = prices[chainAssetId] ?? PriceData.zero()
        } else {
            priceData = nil
        }

        let balance = try? asset.balanceResult?.get()

        return AssetListAssetAccountInfo(
            assetId: asset.assetModel.assetId,
            assetInfo: assetInfo,
            balance: balance,
            priceData: priceData
        )
    }

    func didReceivePrices(result: Result<[ChainAssetId: PriceData], Error>?) {
        guard let result = result else {
            return
        }

        priceResult = result

        for chain in allChains.values {
            let models = chain.assets.map { asset in
                createAssetModel(for: chain, assetModel: asset)
            }

            let changes: [DataProviderChange<AssetListAssetModel>] = models.map { model in
                .update(newItem: model)
            }

            groupLists[chain.chainId]?.apply(changes: changes)

            let groupModel = createGroupModel(from: chain, assets: models)
            groups.apply(changes: [.update(newItem: groupModel)])
        }
    }

    func didReceiveChainModelChanges(_ changes: [DataProviderChange<ChainModel>]) {
        var groupChanges: [DataProviderChange<AssetListGroupModel>] = []
        for change in changes {
            switch change {
            case let .insert(newItem):
                let assets = createAssetModels(for: newItem)
                let assetsCalculator = Self.createAssetsDiffCalculator(from: assets)
                groupLists[newItem.chainId] = assetsCalculator

                let groupModel = createGroupModel(from: newItem, assets: assets)
                groupChanges.append(.insert(newItem: groupModel))
            case let .update(newItem):
                let assets = createAssetModels(for: newItem)

                groupLists[newItem.chainId] = Self.createAssetsDiffCalculator(from: assets)

                let groupModel = createGroupModel(from: newItem, assets: assets)
                groupChanges.append(.update(newItem: groupModel))

            case let .delete(deletedIdentifier):
                groupLists[deletedIdentifier] = nil
                groupChanges.append(.delete(deletedIdentifier: deletedIdentifier))
            }
        }

        storeChainChanges(changes)

        groups.apply(changes: groupChanges)
    }

    func didReceiveBalance(results: [ChainAssetId: Result<CalculatedAssetBalance?, Error>]) {
        var assetsChanges: [ChainModel.Id: [DataProviderChange<AssetListAssetModel>]] = [:]
        var changedGroups: [ChainModel.Id: ChainModel] = [:]

        for (chainAssetId, result) in results {
            switch result {
            case let .success(maybeAmount):
                if let amount = maybeAmount {
                    balanceResults[chainAssetId] = .success(amount.total)
                    amount.balance.map {
                        balances[chainAssetId] = .success($0)
                    }
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

            let assetListModel = createAssetModel(for: chainModel, assetModel: assetModel)
            var chainChanges = assetsChanges[chainAssetId.chainId] ?? []
            chainChanges.append(.update(newItem: assetListModel))
            assetsChanges[chainAssetId.chainId] = chainChanges

            changedGroups[chainModel.chainId] = chainModel
        }

        for (chainId, changes) in assetsChanges {
            groupLists[chainId]?.apply(changes: changes)
        }

        let groupChanges: [DataProviderChange<AssetListGroupModel>] = changedGroups.map { keyValue in
            let chainId = keyValue.key
            let chainModel = keyValue.value

            let allItems = groupLists[chainId]?.allItems ?? []
            let groupModel = createGroupModel(from: chainModel, assets: allItems)

            return .update(newItem: groupModel)
        }

        groups.apply(changes: groupChanges)
    }

    func didReceive(locks: [AssetLock]) {
        allLocks = locks
    }
}
