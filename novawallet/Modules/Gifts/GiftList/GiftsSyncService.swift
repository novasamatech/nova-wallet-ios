import Foundation
import Operation_iOS

protocol GiftsSyncServiceDelegate: AnyObject {
    func giftsSyncService(
        _ service: GiftsSyncServiceProtocol,
        didUpdateSyncingAccountIds accountIds: Set<AccountId>
    )
}

protocol GiftsSyncServiceProtocol: AnyObject {
    var delegate: GiftsSyncServiceDelegate? { get set }

    func start()
}

final class GiftsSyncService {
    weak var delegate: GiftsSyncServiceDelegate?

    let giftsLocalSubscriptionFactory: GiftsLocalSubscriptionFactoryProtocol
    let giftRepository: AnyDataProviderRepository<GiftModel>
    let syncer: GiftsSyncerProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    var giftsLocalSubscription: StreamableProvider<GiftModel>?

    private let gifts = InMemoryCache<GiftModel.Id, GiftModel>()

    init(
        giftsLocalSubscriptionFactory: GiftsLocalSubscriptionFactoryProtocol,
        giftRepository: AnyDataProviderRepository<GiftModel>,
        syncer: GiftsSyncerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.giftsLocalSubscriptionFactory = giftsLocalSubscriptionFactory
        self.giftRepository = giftRepository
        self.syncer = syncer
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        clearSubscriptions()
    }
}

// MARK: - Private

private extension GiftsSyncService {
    func setup() {
        syncer.delegate = self
        giftsLocalSubscription = subscribeAllGifts()
    }

    func clearSubscriptions() {
        syncer.stopSyncing()
        giftsLocalSubscription = nil
        gifts.removeAllValues()
    }

    func updateSubscriptions(for changes: [DataProviderChange<GiftModel>]) {
        changes
            .compactMap(\.item)
            .filter { $0.status == .pending }
            .forEach { syncer.startSyncing(for: $0) }

        changes
            .compactMap(\.item)
            .filter { $0.status == .claimed || $0.status == .reclaimed }
            .forEach { syncer.stopSyncing(for: $0.giftAccountId) }
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

// MARK: - GiftsSyncerDelegate

extension GiftsSyncService: GiftsSyncerDelegate {
    func giftsSyncer(
        _ syncer: GiftsSyncer,
        didReceive status: GiftModel.Status,
        for giftAccountId: AccountId
    ) {
        guard
            let gift = gifts.fetchValue(for: giftAccountId.toHex()),
            gift.status != .reclaimed
        else { return }

        updateGiftStatusIfNeeded(gift: gift, newStatus: status)
    }

    func giftsSyncer(
        _ syncer: GiftsSyncer,
        didUpdateSyncingAccountIds accountIds: Set<AccountId>
    ) {
        delegate?.giftsSyncService(
            self,
            didUpdateSyncingAccountIds: accountIds
        )
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
    func start() {
        setup()
    }
}
