import UIKit
import RobinHood

enum NftListInteractorError: Error {
    case nftUnavailable
}

final class NftListInteractor {
    weak var presenter: NftListInteractorOutputProtocol!

    let wallet: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let nftLocalSubscriptionFactory: NftLocalSubscriptionFactoryProtocol

    private var nfts: [NftModel.Id: NftChainModel] = [:]
    private var nftChains: [ChainModel.Id: ChainModel] = [:]
    private var nftPrices: [AssetModel.PriceId: PriceData] = [:]
    private var priceProviders: [AssetModel.PriceId: AnySingleValueProvider<PriceData>] = [:]

    private var nftProvider: StreamableProvider<NftModel>?

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        nftLocalSubscriptionFactory: NftLocalSubscriptionFactoryProtocol
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.nftLocalSubscriptionFactory = nftLocalSubscriptionFactory
    }

    private func updateNftsFromModel(changes: [DataProviderChange<NftModel>]) -> [DataProviderChange<NftChainModel>] {
        let nftChanges: [DataProviderChange<NftChainModel>] = changes.compactMap { change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                if let nftChain = nfts[newItem.identifier] {
                    let newNftChain = NftChainModel(
                        nft: newItem,
                        chainAsset: nftChain.chainAsset,
                        price: nftChain.price
                    )
                    return .update(newItem: newNftChain)
                } else if let chainAsset = getNftChainAsset(for: newItem.chainId) {
                    let price = getNftPrice(for: newItem.chainId)
                    let newNftChain = NftChainModel(nft: newItem, chainAsset: chainAsset, price: price)
                    return .insert(newItem: newNftChain)
                } else {
                    return nil
                }
            case let .delete(deletedIdentifier):
                if nfts[deletedIdentifier] != nil {
                    return .delete(deletedIdentifier: deletedIdentifier)
                } else {
                    return nil
                }
            }
        }

        nftChanges.forEach { change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                nfts[newItem.nft.identifier] = newItem
            case let .delete(deletedIdentifier):
                nfts[deletedIdentifier] = nil
            }
        }

        return nftChanges
    }

    private func updateNftsFromPrice(
        _ priceData: PriceData,
        priceId: AssetModel.PriceId
    ) -> [DataProviderChange<NftChainModel>] {
        nftPrices[priceId] = priceData

        let changeModels: [NftChainModel] = nfts.compactMap { _, nftChainModel in
            guard nftChainModel.chainAsset.asset.priceId == priceId else {
                return nil
            }

            return NftChainModel(nft: nftChainModel.nft, chainAsset: nftChainModel.chainAsset, price: priceData)
        }

        let changes: [DataProviderChange<NftChainModel>] = changeModels.map { .update(newItem: $0) }

        for changedModel in changeModels {
            nfts[changedModel.nft.identifier] = changedModel
        }

        return changes
    }

    private func subscribeChains() {
        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
            self?.updateNftsFromChain(changes: changes)
        }
    }

    private func updateNftsFromChain(changes: [DataProviderChange<ChainModel>]) {
        var nftChanges: [DataProviderChange<NftChainModel>] = []
        var hasChanges: Bool = false

        for change in changes {
            let removals = removeNfts(for: change)
            nftChanges.append(contentsOf: removals)

            let newHasChanges = updateNftChains(from: change)
            hasChanges = hasChanges || newHasChanges
        }

        if !nftChanges.isEmpty {
            presenter.didReceiveNft(changes: nftChanges)
        }

        if hasChanges {
            updateNftProvider()
        }

        updatePriceProviders()
    }

    private func updateNftProvider() {
        let allChains = Array(nftChains.values)

        nftProvider?.removeObserver(self)
        nftProvider = nil

        if !allChains.isEmpty {
            nftProvider = subscribeToNftProvider(for: wallet, chains: allChains)
        }
    }

    private func getNftChainAsset(for chainId: ChainModel.Id) -> ChainAsset? {
        guard let chain = nftChains[chainId], let asset = chain.utilityAssets().first else {
            return nil
        }

        return ChainAsset(chain: chain, asset: asset)
    }

    private func getNftPrice(for chainId: ChainModel.Id) -> PriceData? {
        guard let chain = nftChains[chainId], let priceId = chain.utilityAssets().first?.priceId else {
            return nil
        }

        return nftPrices[priceId]
    }

    private func updatePriceProviders() {
        let newPriceIds: [AssetModel.PriceId] = nftChains.values.compactMap { chain in
            guard let priceId = chain.utilityAssets().first?.priceId else {
                return nil
            }

            return priceId
        }

        let newPriceIdSet = Set(newPriceIds)

        priceProviders = priceProviders.filter { keyValue in
            newPriceIdSet.contains(keyValue.key)
        }

        let currentPriceSet = Set(priceProviders.keys)

        let priceIdsToAdd = newPriceIdSet.symmetricDifference(currentPriceSet)

        priceIdsToAdd.forEach { priceId in
            let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false, waitsInProgressSyncOnAdd: false)
            priceProviders[priceId] = subscribeToPrice(for: priceId, options: options)
        }
    }

    private func updateNftChains(from change: DataProviderChange<ChainModel>) -> Bool {
        switch change {
        case let .insert(newItem), let .update(newItem):
            if newItem.nftSources.isEmpty, let chainId = nftChains[newItem.chainId]?.chainId {
                nftChains[chainId] = nil
                return true
            }

            if !newItem.nftSources.isEmpty, nftChains[newItem.chainId] == nil {
                nftChains[newItem.chainId] = newItem

                return true
            }

            return false

        case let .delete(deletedIdentifier):
            let hasChanges = nftChains[deletedIdentifier] != nil
            nftChains[deletedIdentifier] = nil

            return hasChanges
        }
    }

    private func removeNfts(for change: DataProviderChange<ChainModel>) -> [DataProviderChange<NftChainModel>] {
        switch change {
        case let .insert(newItem), let .update(newItem):
            if newItem.nftSources.isEmpty {
                return removeNfts(for: newItem.identifier)
            } else {
                return []
            }
        case let .delete(deletedIdentifier):
            return removeNfts(for: deletedIdentifier)
        }
    }

    private func removeNfts(for chainId: ChainModel.Id) -> [DataProviderChange<NftChainModel>] {
        let nftsToRemove = nfts.filter { $0.value.chainAsset.chain.chainId == chainId }

        nfts = nfts.filter { nftsToRemove[$0.key] != nil }

        return nftsToRemove.keys.map { .delete(deletedIdentifier: $0) }
    }
}

extension NftListInteractor: NftListInteractorInputProtocol {
    func setup() {
        subscribeChains()
    }

    func refresh() {
        nftProvider?.refresh()
    }

    func getNftForId(_ identifier: NftModel.Id) {
        guard let nft = nfts[identifier] else {
            presenter.didReceive(error: NftListInteractorError.nftUnavailable)
            return
        }

        presenter.didReceiveNft(nft)
    }
}

extension NftListInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        switch result {
        case let .success(optionalPriceData):
            if let priceData = optionalPriceData {
                let changes = updateNftsFromPrice(priceData, priceId: priceId)
                presenter.didReceiveNft(changes: changes)
            }
        case let .failure(error):
            presenter.didReceive(error: error)
        }
    }
}

extension NftListInteractor: NftLocalStorageSubscriber, NftLocalSubscriptionHandler {
    func handleNfts(result: Result<[DataProviderChange<NftModel>], Error>, wallet _: MetaAccountModel) {
        switch result {
        case let .success(changes):
            let changes = updateNftsFromModel(changes: changes)
            presenter.didReceiveNft(changes: changes)
        case let .failure(error):
            presenter.didReceive(error: error)
        }
    }
}
