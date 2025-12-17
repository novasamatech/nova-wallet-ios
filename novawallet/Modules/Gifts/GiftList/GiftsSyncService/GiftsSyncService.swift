import Foundation
import Operation_iOS

protocol GiftsSyncServiceProtocol: AnyObject {
    func add(
        observer: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<GiftsSyncAccounts?>.StateChangeClosure
    )

    func remove(observer: AnyObject)

    func setup()
}

typealias GiftsSyncAccounts = Set<AccountId>

final class GiftsSyncService: BaseObservableStateStore<GiftsSyncAccounts> {
    let giftsLocalSubscriptionFactory: GiftsLocalSubscriptionFactoryProtocol
    let giftRepository: AnyDataProviderRepository<GiftModel>
    let statusTracker: GiftsStatusTrackerProtocol
    let operationQueue: OperationQueue

    var giftsLocalSubscription: StreamableProvider<GiftModel>?

    private let gifts = InMemoryCache<GiftModel.Id, GiftModel>()

    init(
        giftsLocalSubscriptionFactory: GiftsLocalSubscriptionFactoryProtocol,
        giftRepository: AnyDataProviderRepository<GiftModel>,
        statusTracker: GiftsStatusTrackerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.giftsLocalSubscriptionFactory = giftsLocalSubscriptionFactory
        self.giftRepository = giftRepository
        self.statusTracker = statusTracker
        self.operationQueue = operationQueue

        super.init(logger: logger)
    }

    deinit {
        clearSubscriptions()
    }
}

// MARK: - Private

private extension GiftsSyncService {
    func clearSubscriptions() {
        statusTracker.stopTracking()
        giftsLocalSubscription = nil
        gifts.removeAllValues()
    }

    func updateSubscriptions(for changes: [DataProviderChange<GiftModel>]) {
        changes
            .compactMap(\.item)
            .filter { $0.status == .pending }
            .forEach { statusTracker.startTracking(for: $0) }

        changes
            .compactMap(\.item)
            .filter { $0.status == .claimed || $0.status == .reclaimed }
            .forEach { statusTracker.stopTracking(for: $0.giftAccountId) }
    }

    func updateGiftStatusIfNeeded(gift: GiftModel, newStatus: GiftModel.Status) {
        guard gift.status != newStatus else { return }

        let saveOperation = giftRepository.saveOperation(
            { [gift.updating(status: newStatus)] },
            { [] }
        )

        operationQueue.addOperations([saveOperation], waitUntilFinished: false)
    }
}

// MARK: - GiftsStatusTrackerDelegate

extension GiftsSyncService: GiftsStatusTrackerDelegate {
    func giftsTracker(
        _: GiftsStatusTrackerProtocol,
        didReceive status: GiftModel.Status,
        for giftAccountId: AccountId
    ) {
        guard
            let gift = gifts.fetchValue(for: giftAccountId.toHex()),
            gift.status != .reclaimed
        else { return }

        updateGiftStatusIfNeeded(gift: gift, newStatus: status)
    }

    func giftsTracker(
        _: GiftsStatusTrackerProtocol,
        didUpdateTrackingAccountIds accountIds: Set<AccountId>
    ) {
        stateObservable.state = accountIds
    }
}

// MARK: - GiftsLocalStorageSubscriber

extension GiftsSyncService: GiftsLocalStorageSubscriber, GiftsLocalSubscriptionHandler {
    func handleAllGifts(result: Result<[DataProviderChange<GiftModel>], any Error>) {
        switch result {
        case let .success(changes):
            changes.forEach { change in
                switch change {
                case let .insert(gift), let .update(gift):
                    gifts.store(value: gift, for: gift.identifier)
                case let .delete(deletedIdentifier):
                    gifts.removeValue(for: deletedIdentifier)
                }
            }
            updateSubscriptions(for: changes)
        case let .failure(error):
            logger.error("Failed on gifts subscription: \(error)")
        }
    }
}

// MARK: - GiftsSyncServiceProtocol

extension GiftsSyncService: GiftsSyncServiceProtocol {
    func setup() {
        mutex.lock()
        defer { mutex.unlock() }

        guard giftsLocalSubscription == nil else { return }

        statusTracker.delegate = self
        giftsLocalSubscription = subscribeAllGifts()
    }
}
