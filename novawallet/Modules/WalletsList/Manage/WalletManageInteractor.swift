import Foundation
import Operation_iOS

final class WalletManageInteractor: WalletsListInteractor {
    let walletUpdateMediator: WalletUpdateMediating
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
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.cloudBackupSyncService = cloudBackupSyncService
        self.walletUpdateMediator = walletUpdateMediator
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
                eventCenter.notify(with: SelectedAccountChanged())
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
            self.eventCenter.notify(with: AccountsRemovedManually())
            self.handleWalletsUpdate(result: result)
        }
    }
}
