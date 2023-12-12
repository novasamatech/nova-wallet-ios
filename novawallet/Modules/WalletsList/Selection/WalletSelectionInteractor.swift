import Foundation
import RobinHood

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
    private var proxies: [ManagedMetaAccountModel: ChainAccountModel] = [:]
    let metaAccountRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
    private let operationQueue: OperationQueue

    init(
        balancesStore: BalancesStoreProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        metaAccountRepository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        settings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue
    ) {
        self.settings = settings
        self.eventCenter = eventCenter
        self.metaAccountRepository = metaAccountRepository
        self.operationQueue = operationQueue
        super.init(
            balancesStore: balancesStore,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            walletListLocalSubscriptionFactory: walletListLocalSubscriptionFactory
        )
    }

    override func applyWallets(changes: [DataProviderChange<ManagedMetaAccountModel>]) {
        super.applyWallets(changes: changes)

        proxies = changes.reduce(into: proxies) { result, change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                if let chainAccount = newItem.info.chainAccounts.first(where: { $0.proxy != nil }),
                   let proxy = chainAccount.proxy {
                    result[newItem] = chainAccount
                }
            case let .delete(deletedIdentifier):
                break
            }
        }
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

    func updateWalletsStatuses() {
        let newProxyWallets = proxies.filter { $0.value.proxy?.status == .new }.map {
            $0.key.replacingInfo($0.key.info.replacingChainAccount($0.value.replacingProxyStatus(.active)))
        }.compactMap { $0 }
        let revokedProxyWallets = proxies
            .filter { $0.value.proxy?.status == .revoked }
            .map(\.key.identifier)
            .compactMap { $0 }

        let saveOperation = metaAccountRepository.saveOperation(
            { newProxyWallets },
            { revokedProxyWallets }
        )

        execute(
            operation: saveOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.didUpdateWallets()
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }
}

extension ChainAccountModel {
    func replacingProxyStatus(_ status: ProxyAccountModel.Status) -> ChainAccountModel {
        guard let proxy = self.proxy else {
            return self
        }

        return .init(
            chainId: chainId,
            accountId: accountId,
            publicKey: publicKey,
            cryptoType: cryptoType,
            proxy: .init(type: proxy.type, accountId: proxy.accountId, status: status)
        )
    }
}
