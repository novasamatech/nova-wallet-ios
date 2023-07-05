import Foundation
import BigInt
import RobinHood

class AssetListBaseBuilder {
    let workingQueue: DispatchQueue
    let callbackQueue: DispatchQueue

    private(set) var wallet: MetaAccountModel?

    private(set) var groups: ListDifferenceCalculator<AssetListGroupModel>
    private(set) var groupLists: [ChainModel.Id: ListDifferenceCalculator<AssetListAssetModel>] = [:]

    private(set) var priceResult: Result<[ChainAssetId: PriceData], Error>?
    private(set) var balanceResults: [ChainAssetId: Result<BigUInt, Error>] = [:]
    private(set) var balances: [ChainAssetId: Result<AssetBalance, Error>] = [:]
    private(set) var allChains: [ChainModel.Id: ChainModel] = [:]
    private(set) var crowdloansResult: Result<[ChainModel.Id: [CrowdloanContributionData]], Error>?

    init(
        workingQueue: DispatchQueue,
        callbackQueue: DispatchQueue
    ) {
        self.workingQueue = workingQueue
        self.callbackQueue = callbackQueue
        groups = AssetListModelHelpers.createGroupsDiffCalculator(from: [])
    }

    func rebuildModel() {
        fatalError("Must be overriden by subsclass")
    }

    func resetStorages() {
        allChains = [:]
        balanceResults = [:]
        balances = [:]
        groups = AssetListModelHelpers.createGroupsDiffCalculator(from: [])
        groupLists = [:]
        crowdloansResult = nil
    }

    private func updateAssetModels() {
        let state = AssetListState(
            priceResult: priceResult,
            balanceResults: balanceResults,
            allChains: allChains,
            crowdloansResult: crowdloansResult
        )

        for chain in allChains.values {
            let models = chain.assets.map { asset in
                AssetListModelHelpers.createAssetModel(for: chain, assetModel: asset, state: state)
            }

            let changes: [DataProviderChange<AssetListAssetModel>] = models.map { model in
                .update(newItem: model)
            }

            groupLists[chain.chainId]?.apply(changes: changes)

            let groupModel = AssetListModelHelpers.createGroupModel(from: chain, assets: models)
            groups.apply(changes: [.update(newItem: groupModel)])
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

    private func processChainChanges(_ changes: [DataProviderChange<ChainModel>]) {
        let state = AssetListState(
            priceResult: priceResult,
            balanceResults: balanceResults,
            allChains: allChains,
            crowdloansResult: crowdloansResult
        )

        var groupChanges: [DataProviderChange<AssetListGroupModel>] = []
        for change in changes {
            switch change {
            case let .insert(newItem):
                let assets = AssetListModelHelpers.createAssetModels(for: newItem, state: state)
                let assetsCalculator = AssetListModelHelpers.createAssetsDiffCalculator(from: assets)
                groupLists[newItem.chainId] = assetsCalculator

                let groupModel = AssetListModelHelpers.createGroupModel(from: newItem, assets: assets)
                groupChanges.append(.insert(newItem: groupModel))
            case let .update(newItem):
                let assets = AssetListModelHelpers.createAssetModels(for: newItem, state: state)

                groupLists[newItem.chainId] = AssetListModelHelpers.createAssetsDiffCalculator(from: assets)

                let groupModel = AssetListModelHelpers.createGroupModel(from: newItem, assets: assets)
                groupChanges.append(.update(newItem: groupModel))

            case let .delete(deletedIdentifier):
                groupLists[deletedIdentifier] = nil
                groupChanges.append(.delete(deletedIdentifier: deletedIdentifier))
            }
        }

        storeChainChanges(changes)

        groups.apply(changes: groupChanges)
    }

    private func processBalances(_ results: [ChainAssetId: Result<CalculatedAssetBalance?, Error>]) {
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

            let state = AssetListState(
                priceResult: priceResult,
                balanceResults: balanceResults,
                allChains: allChains,
                crowdloansResult: crowdloansResult
            )

            let assetListModel = AssetListModelHelpers.createAssetModel(
                for: chainModel,
                assetModel: assetModel,
                state: state
            )
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
            let groupModel = AssetListModelHelpers.createGroupModel(from: chainModel, assets: allItems)

            return .update(newItem: groupModel)
        }

        groups.apply(changes: groupChanges)
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

    private func processCrowdloans(_ result: Result<[ChainModel.Id: [CrowdloanContributionData]], Error>) {
        crowdloansResult = result
        updateAssetModels()
    }
}

extension AssetListBaseBuilder {
    func applyChainModelChanges(_ changes: [DataProviderChange<ChainModel>]) {
        workingQueue.async { [weak self] in
            self?.processChainChanges(changes)

            self?.rebuildModel()
        }
    }

    func applyBalances(_ results: [ChainAssetId: Result<CalculatedAssetBalance?, Error>]) {
        workingQueue.async { [weak self] in
            self?.processBalances(results)

            self?.rebuildModel()
        }
    }

    func applyCrowdloans(_ result: Result<[ChainModel.Id: [CrowdloanContributionData]], Error>) {
        workingQueue.async { [weak self] in
            self?.processCrowdloans(result)

            self?.rebuildModel()
        }
    }

    func applyPriceChanges(_ priceChanges: [ChainAssetId: DataProviderChange<PriceData>]) {
        workingQueue.async { [weak self] in
            self?.processPriceChanges(priceChanges)

            self?.rebuildModel()
        }
    }

    func applyPrice(error: Error) {
        workingQueue.async { [weak self] in
            if let self = self, self.priceResult == nil {
                self.priceResult = .failure(error)

                self.updateAssetModels()
                self.rebuildModel()
            }
        }
    }

    func applyWallet(_ wallet: MetaAccountModel) {
        workingQueue.async { [weak self] in
            self?.wallet = wallet

            self?.resetStorages()

            self?.rebuildModel()
        }
    }
}
