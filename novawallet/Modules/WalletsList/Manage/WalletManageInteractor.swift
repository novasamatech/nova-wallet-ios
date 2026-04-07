import Foundation
import Operation_iOS

final class WalletManageInteractor: WalletsListInteractor {
    let walletUpdateMediator: WalletUpdateMediating
    let walletFavouriteRepository: WalletFavouriteRepositoryProtocol
    let cloudBackupSyncService: CloudBackupSyncServiceProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    var presenter: WalletManageInteractorOutputProtocol? {
        get {
            basePresenter as? WalletManageInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    init(
        cloudBackupSyncService: CloudBackupSyncServiceProtocol,
        balancesStore: BalancesStoreProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        walletUpdateMediator: WalletUpdateMediating,
        walletFavouriteRepository: WalletFavouriteRepositoryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.cloudBackupSyncService = cloudBackupSyncService
        self.walletUpdateMediator = walletUpdateMediator
        self.walletFavouriteRepository = walletFavouriteRepository
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.logger = logger

        super.init(
            balancesStore: balancesStore,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            walletListLocalSubscriptionFactory: walletListLocalSubscriptionFactory
        )
    }

    private func handleWalletsUpdate(result: Result<WalletUpdateMediatingResult, Error>) {
        switch result {
        case let .success(update):
            if update.isWalletSwitched {
                eventCenter.notify(with: SelectedWalletSwitched())
            }

            if update.selectedWallet == nil {
                presenter?.didRemoveAllWallets()
            }
        case let .failure(error):
            logger.error("Did receive wallet update error: \(error)")
        }
    }

    private func subscribeCloudBackupState() {
        cloudBackupSyncService.subscribeState(
            self,
            notifyingIn: .main
        ) { [weak self] state in
            self?.presenter?.didReceiveCloudBackup(state: state)
        }
    }

    override func setup() {
        super.setup()

        subscribeCloudBackupState()
    }
}

extension WalletManageInteractor: WalletManageInteractorInputProtocol {
    func save(items: [ManagedMetaAccountModel]) {
        let wrapper = walletUpdateMediator.saveChanges {
            SyncChanges(newOrUpdatedItems: items, removedItems: [])
        }

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { result in
            self.handleWalletsUpdate(result: result)
        }
    }

    func remove(item: ManagedMetaAccountModel) {
        let wrapper = walletUpdateMediator.saveChanges {
            SyncChanges(newOrUpdatedItems: [], removedItems: [item])
        }

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { result in
            self.eventCenter.notify(with: WalletRemoved())
            self.handleWalletsUpdate(result: result)
        }
    }

    func toggleFavourite(metaId: MetaAccountModel.Id) {
        // Bypasses WalletUpdateMediator on purpose: isFavourite is local-only
        // metadata and not part of the cloud backup payload, so a star tap
        // should not trigger a backup sync. The wallets-list local subscription
        // observing the underlying store still picks up the change and the UI
        // refreshes through the standard didReceiveWalletsChanges path.
        let wrapper = walletFavouriteRepository.toggleFavouriteWrapper(for: metaId)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.logger.error("Toggle favourite failed: \(error)")
            }
        }
    }
}
