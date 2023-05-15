import Foundation

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

    init(
        balancesStore: BalancesStoreProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        settings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol
    ) {
        self.settings = settings
        self.eventCenter = eventCenter

        super.init(
            balancesStore: balancesStore,
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
                self?.eventCenter.notify(with: SelectedAccountChanged())

                self?.presenter?.didCompleteSelection()
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }
}
