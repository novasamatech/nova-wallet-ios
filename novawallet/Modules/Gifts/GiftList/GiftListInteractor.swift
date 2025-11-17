import UIKit
import Operation_iOS

final class GiftListInteractor {
    weak var presenter: GiftListInteractorOutputProtocol?

    let giftsLocalSubscriptionFactory: GiftsLocalSubscriptionFactoryProtocol

    let giftSyncService: GiftsSyncServiceProtocol
    let operationQueue: OperationQueue

    var giftsLocalSubscription: StreamableProvider<GiftModel>?

    init(
        giftsLocalSubscriptionFactory: GiftsLocalSubscriptionFactoryProtocol,
        giftSyncService: GiftsSyncServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.giftsLocalSubscriptionFactory = giftsLocalSubscriptionFactory
        self.giftSyncService = giftSyncService
        self.operationQueue = operationQueue
    }
}

// MARK: - Private

private extension GiftListInteractor {}

// MARK: - GiftsLocalStorageSubscriber

extension GiftListInteractor: GiftsLocalStorageSubscriber, GiftsLocalSubscriptionHandler {
    func handleAllGifts(result: Result<[DataProviderChange<GiftModel>], any Error>) {
        switch result {
        case let .success(changes):
            presenter?.didReceive(changes)
        case let .failure(error):
            presenter?.didReceive(error)
        }
    }
}

// MARK: - GiftListInteractorInputProtocol

extension GiftListInteractor: GiftListInteractorInputProtocol {
    func setup() {
        giftsLocalSubscription = subscribeAllGifts()
        giftSyncService.start()
    }
}
