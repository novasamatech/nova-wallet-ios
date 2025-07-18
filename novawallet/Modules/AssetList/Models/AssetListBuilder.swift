import Foundation
import Operation_iOS

final class AssetListBuilder: AssetListBaseBuilder {
    let resultClosure: (AssetListBuilderResult) -> Void

    private(set) var nftList: ListDifferenceCalculator<NftModel>
    private(set) var pendingOperations: [String: Multisig.PendingOperation]
    private(set) var locksResult: Result<[AssetLock], Error>?
    private(set) var holdsResult: Result<[AssetHold], Error>?

    private var currentModel: AssetListBuilderResult.Model = .init()

    init(
        workingQueue: DispatchQueue = .init(label: "com.nova.wallet.assets.builder", qos: .userInteractive),
        callbackQueue: DispatchQueue = .main,
        rebuildPeriod: TimeInterval = 1.0,
        resultClosure: @escaping (AssetListBuilderResult) -> Void
    ) {
        self.resultClosure = resultClosure
        nftList = AssetListModelHelpers.createNftDiffCalculator()
        pendingOperations = [:]

        super.init(workingQueue: workingQueue, callbackQueue: callbackQueue, rebuildPeriod: rebuildPeriod)
    }

    override func rebuildModel() {
        var groupListByChain: [ChainModel.Id: [AssetListAssetModel]] = [:]
        var groupListsByChainDiff: [ChainModel.Id: [ListDifference<AssetListAssetModel>]] = [:]

        groupListsByChain.forEach { key, value in
            groupListByChain[key] = value.allItems
            groupListsByChainDiff[key] = value.lastDifferences
        }

        var groupListByAsset: [AssetModel.Symbol: [AssetListAssetModel]] = [:]
        var groupListsByAssetDiff: [AssetModel.Symbol: [ListDifference<AssetListAssetModel>]] = [:]

        groupListsByAsset.forEach { key, value in
            groupListByAsset[key] = value.allItems
            groupListsByAssetDiff[key] = value.lastDifferences
        }

        let model = AssetListBuilderResult.Model(
            chainGroups: chainGroups.allItems,
            assetGroups: assetGroups.allItems,
            groupListsByChain: groupListByChain,
            groupListsByAsset: groupListByAsset,
            priceResult: priceResult,
            balanceResults: balanceResults,
            allChains: allChains,
            balances: balances,
            externalBalanceResult: externalBalancesResult,
            nfts: nftList.allItems,
            pendingOperations: Array(pendingOperations.values),
            locksResult: locksResult,
            holdsResult: holdsResult
        )

        currentModel = model

        let result = AssetListBuilderResult(
            walletId: wallet?.metaId,
            model: model,
            changeKind: .reload
        )

        callbackQueue.async { [weak self] in
            self?.resultClosure(result)
        }
    }

    func rebuildPendingOperationsOnly() {
        let model = currentModel.replacing(
            pendingOperations: Array(pendingOperations.values)
        )
        currentModel = model

        let result = AssetListBuilderResult(
            walletId: wallet?.metaId,
            model: model,
            changeKind: .pendingOperations
        )

        callbackQueue.async { [weak self] in
            self?.resultClosure(result)
        }
    }

    func rebuildNftOnly() {
        let model = currentModel.replacing(nfts: nftList.allItems)
        currentModel = model

        let result = AssetListBuilderResult(
            walletId: wallet?.metaId,
            model: model,
            changeKind: .nfts
        )

        callbackQueue.async { [weak self] in
            self?.resultClosure(result)
        }
    }

    override func resetStorages() {
        super.resetStorages()

        nftList = AssetListModelHelpers.createNftDiffCalculator()
        pendingOperations = [:]
        locksResult = nil
        currentModel = .init()
    }
}

extension AssetListBuilder {
    func applyNftChanges(_ changes: [DataProviderChange<NftModel>]) {
        workingQueue.async { [weak self] in
            self?.nftList.apply(changes: changes)

            self?.rebuildNftOnly()
        }
    }

    func applyNftReset() {
        workingQueue.async { [weak self] in
            self?.nftList = AssetListModelHelpers.createNftDiffCalculator()

            self?.rebuildNftOnly()
        }
    }

    func applyPendingOperationsChanges(_ changes: [DataProviderChange<Multisig.PendingOperation>]) {
        workingQueue.async { [weak self] in
            self?.pendingOperations = changes.mergeToDict(self?.pendingOperations ?? [:])

            self?.rebuildPendingOperationsOnly()
        }
    }

    func applyPendingOperationsReset() {
        workingQueue.async { [weak self] in
            self?.pendingOperations = [:]

            self?.rebuildPendingOperationsOnly()
        }
    }

    func applyLocks(_ result: Result<[AssetLock], Error>) {
        workingQueue.async { [weak self] in
            self?.locksResult = result

            self?.scheduleRebuildModel()
        }
    }

    func applyHolds(_ result: Result<[AssetHold], Error>) {
        workingQueue.async { [weak self] in
            self?.holdsResult = result

            self?.scheduleRebuildModel()
        }
    }
}
