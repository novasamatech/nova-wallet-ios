import UIKit
import Operation_iOS

final class GiftListInteractor {
    weak var presenter: GiftListInteractorOutputProtocol?

    let selectedMetaId: MetaAccountModel.Id

    let chainRegistry: ChainRegistryProtocol
    let giftsLocalSubscriptionFactory: GiftsLocalSubscriptionFactoryProtocol

    let giftSyncService: GiftsSyncServiceProtocol
    let operationQueue: OperationQueue

    var giftsLocalSubscription: StreamableProvider<GiftModel>?
    var chainAssets: [ChainAssetId: ChainAsset] = [:]

    init(
        chainRegistry: ChainRegistryProtocol,
        giftsLocalSubscriptionFactory: GiftsLocalSubscriptionFactoryProtocol,
        giftSyncService: GiftsSyncServiceProtocol,
        selectedMetaId: MetaAccountModel.Id,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.giftsLocalSubscriptionFactory = giftsLocalSubscriptionFactory
        self.giftSyncService = giftSyncService
        self.selectedMetaId = selectedMetaId
        self.operationQueue = operationQueue
    }

    deinit {
        giftSyncService.remove(observer: self)
    }
}

// MARK: - Private

private extension GiftListInteractor {
    func setupChainAssets() {
        chainAssets = chainRegistry.availableChainIds?
            .reduce(into: [:]) { acc, chainId in
                chainRegistry.getChain(for: chainId)?.chainAssets().forEach {
                    acc[$0.chainAssetId] = $0
                }
            } ?? [:]
    }

    func subscribeGiftSync() {
        giftSyncService.add(
            observer: self,
            sendStateOnSubscription: false,
            queue: .main
        ) { [weak self] _, accountIds in
            guard let accountIds else { return }

            self?.presenter?.didReceive(syncingAccountIds: accountIds)
        }

        giftSyncService.setup()
    }

    func subscribeLocalGifts() {
        giftsLocalSubscription = subscribeAllGifts(for: selectedMetaId)
    }
}

// MARK: - GiftsLocalStorageSubscriber

extension GiftListInteractor: GiftsLocalStorageSubscriber, GiftsLocalSubscriptionHandler {
    func handleAllGifts(result: Result<[DataProviderChange<GiftModel>], any Error>) {
        switch result {
        case let .success(changes):
            presenter?.didReceive(changes, chainAssets)
        case let .failure(error):
            presenter?.didReceive(error)
        }
    }
}

// MARK: - GiftListInteractorInputProtocol

extension GiftListInteractor: GiftListInteractorInputProtocol {
    func setup() {
        setupChainAssets()
        subscribeGiftSync()
        subscribeLocalGifts()
    }
}
