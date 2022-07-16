import Foundation
import RobinHood
import BigInt

class WalletListBasePresenter: WalletListBaseInteractorOutputProtocol {
    private(set) var groups: ListDifferenceCalculator<WalletListGroupModel>
    private(set) var groupLists: [ChainModel.Id: ListDifferenceCalculator<WalletListAssetModel>] = [:]

    private(set) var priceResult: Result<[ChainAssetId: PriceData], Error>?
    private(set) var balanceResults: [ChainAssetId: Result<BigUInt, Error>] = [:]
    private(set) var allChains: [ChainModel.Id: ChainModel] = [:]

    init() {
        groups = Self.createGroupsDiffCalculator(from: [])
    }

    func resetStorages() {
        allChains = [:]
        balanceResults = [:]

        groups = Self.createGroupsDiffCalculator(from: [])
        groupLists = [:]
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
        _ groups: ListDifferenceCalculator<WalletListGroupModel>,
        groupLists: [ChainModel.Id: ListDifferenceCalculator<WalletListAssetModel>]
    ) {
        self.groups = groups
        self.groupLists = groupLists
    }

    func createAssetAccountInfo(
        from asset: WalletListAssetModel,
        chain: ChainModel,
        maybePrices: [ChainAssetId: PriceData]?
    ) -> WalletListAssetAccountInfo {
        let assetModel = asset.assetModel
        let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: assetModel.assetId)

        let assetInfo = assetModel.displayInfo(with: chain.icon)

        let priceData: PriceData?

        if let prices = maybePrices {
            priceData = prices[chainAssetId] ?? PriceData(price: "0", usdDayChange: 0)
        } else {
            priceData = nil
        }

        let balance = try? asset.balanceResult?.get()

        return WalletListAssetAccountInfo(
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

            let changes: [DataProviderChange<WalletListAssetModel>] = models.map { model in
                .update(newItem: model)
            }

            groupLists[chain.chainId]?.apply(changes: changes)

            let groupModel = createGroupModel(from: chain, assets: models)
            groups.apply(changes: [.update(newItem: groupModel)])
        }
    }

    func didReceiveChainModelChanges(_ changes: [DataProviderChange<ChainModel>]) {
        var groupChanges: [DataProviderChange<WalletListGroupModel>] = []
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

    func didReceiveBalance(results: [ChainAssetId: Result<BigUInt?, Error>]) {
        var assetsChanges: [ChainModel.Id: [DataProviderChange<WalletListAssetModel>]] = [:]
        var changedGroups: [ChainModel.Id: ChainModel] = [:]

        for (chainAssetId, result) in results {
            switch result {
            case let .success(maybeAmount):
                if let amount = maybeAmount {
                    balanceResults[chainAssetId] = .success(amount)
                } else if balanceResults[chainAssetId] == nil {
                    balanceResults[chainAssetId] = .success(0)
                }
            case let .failure(error):
                balanceResults[chainAssetId] = .failure(error)
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

        let groupChanges: [DataProviderChange<WalletListGroupModel>] = changedGroups.map { keyValue in
            let chainId = keyValue.key
            let chainModel = keyValue.value

            let allItems = groupLists[chainId]?.allItems ?? []
            let groupModel = createGroupModel(from: chainModel, assets: allItems)

            return .update(newItem: groupModel)
        }

        groups.apply(changes: groupChanges)
    }
}
