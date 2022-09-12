import Foundation
import RobinHood

final class WalletManageInteractor: WalletsListInteractor {
    let repository: AnyDataProviderRepository<ManagedMetaAccountModel>
    let operationQueue: OperationQueue
    let selectedWalletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol

    var presenter: WalletManageInteractorOutputProtocol? {
        get {
            basePresenter as? WalletManageInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    init(
        chainRegistry: ChainRegistryProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        repository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        selectedWalletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.repository = repository
        self.operationQueue = operationQueue
        self.selectedWalletSettings = selectedWalletSettings
        self.eventCenter = eventCenter

        super.init(
            chainRegistry: chainRegistry,
            walletListLocalSubscriptionFactory: walletListLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            currencyManager: currencyManager
        )
    }

    private func removeSelectedWalletAndAutoswitch(_ wallet: MetaAccountModel) {
        selectedWalletSettings.remove(value: wallet, runningCompletionIn: .main) { [weak self] result in
            if case let .success(newWallet) = result {
                self?.eventCenter.notify(with: SelectedAccountChanged())

                if newWallet == nil {
                    self?.presenter?.didRemoveAllWallets()
                }
            }
        }
    }

    private func removeNotSelectedWallet(_ wallet: MetaAccountModel) {
        let operation = repository.saveOperation({ [] }, { [wallet.identifier] })
        operationQueue.addOperation(operation)
    }
}

extension WalletManageInteractor: WalletManageInteractorInputProtocol {
    func save(items: [ManagedMetaAccountModel]) {
        let operation = repository.saveOperation({ items }, { [] })
        operationQueue.addOperation(operation)
    }

    func remove(item: ManagedMetaAccountModel) {
        if item.isSelected {
            removeSelectedWalletAndAutoswitch(item.info)
        } else {
            removeNotSelectedWallet(item.info)
        }
    }
}
