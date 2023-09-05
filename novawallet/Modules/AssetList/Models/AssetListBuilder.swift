import Foundation
import RobinHood

final class AssetListBuilder: AssetListBaseBuilder {
    let resultClosure: (AssetListBuilderResult) -> Void

    private(set) var nftList: ListDifferenceCalculator<NftModel>
    private(set) var locksResult: Result<[AssetLock], Error>?

    private var currentModel: AssetListBuilderResult.Model = .init()

    init(
        workingQueue: DispatchQueue = .init(label: "com.nova.wallet.assets.builder", qos: .userInteractive),
        callbackQueue: DispatchQueue = .main,
        rebuildPeriod: TimeInterval = 1.0,
        resultClosure: @escaping (AssetListBuilderResult) -> Void
    ) {
        self.resultClosure = resultClosure
        nftList = AssetListModelHelpers.createNftDiffCalculator()

        super.init(workingQueue: workingQueue, callbackQueue: callbackQueue, rebuildPeriod: rebuildPeriod)
    }

    override func rebuildModel() {
        let groups = self.groups.allItems
        let groupList = groupLists.mapValues { $0.allItems }

        let model = AssetListBuilderResult.Model(
            groups: groups,
            groupLists: groupList,
            priceResult: priceResult,
            balanceResults: balanceResults,
            allChains: allChains,
            balances: balances,
            externalBalanceResult: externalBalancesResult,
            nfts: nftList.allItems,
            locksResult: locksResult
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

    func applyLocks(_ result: Result<[AssetLock], Error>) {
        workingQueue.async { [weak self] in
            self?.locksResult = result

            self?.scheduleRebuildModel()
        }
    }
}
