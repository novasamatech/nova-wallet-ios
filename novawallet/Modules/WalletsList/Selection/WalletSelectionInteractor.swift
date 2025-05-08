import Foundation
import Operation_iOS

final class WalletSelectionInteractor: WalletsListInteractor {
    var presenter: WalletSelectionInteractorOutputProtocol? {
        get {
            basePresenter as? WalletSelectionInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let settings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let proxySyncService: DelegatedAccountSyncServiceProtocol

    init(
        balancesStore: BalancesStoreProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        proxySyncService: DelegatedAccountSyncServiceProtocol,
        settings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol
    ) {
        self.settings = settings
        self.eventCenter = eventCenter
        self.proxySyncService = proxySyncService

        super.init(
            balancesStore: balancesStore,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            walletListLocalSubscriptionFactory: walletListLocalSubscriptionFactory
        )
    }
}

extension WalletSelectionInteractor: WalletSelectionInteractorInputProtocol {
    func select(item: ManagedMetaAccountModel) {
        let oldMetaAccount = settings.value

        guard item.info.identifier != oldMetaAccount?.identifier else {
            return
        }

        settings.save(value: item.info, runningCompletionIn: .main) { [weak self] result in
            switch result {
            case .success:
                self?.eventCenter.notify(with: SelectedWalletSwitched())
                self?.presenter?.didCompleteSelection()
            case let .failure(error):
                self?.presenter?.didReceive(saveError: error)
            }
        }
    }

    func updateWalletsStatuses() {
        proxySyncService.updateWalletsStatuses()
    }
}
