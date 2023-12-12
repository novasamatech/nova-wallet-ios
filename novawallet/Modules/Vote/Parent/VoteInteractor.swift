import Foundation
import RobinHood

final class VoteInteractor {
    weak var presenter: VoteInteractorOutputProtocol?

    let walletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol
    let logger: LoggerProtocol
    private var walletListSubscription: StreamableProvider<ManagedMetaAccountModel>?

    init(
        walletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.walletSettings = walletSettings
        self.eventCenter = eventCenter
        self.walletListLocalSubscriptionFactory = walletListLocalSubscriptionFactory
        self.logger = logger
    }

    private func provideSelectedWallet() {
        guard let selectedWallet = walletSettings.value else {
            return
        }

        presenter?.didReceiveWallet(selectedWallet)
    }
}

extension VoteInteractor: VoteInteractorInputProtocol {
    func setup() {
        provideSelectedWallet()

        eventCenter.add(observer: self, dispatchIn: .main)
        walletListSubscription = subscribeNewProxyWallets()
    }
}

extension VoteInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        provideSelectedWallet()
    }

    func processChainAccountChanged(event _: ChainAccountChanged) {
        provideSelectedWallet()
    }
}

extension VoteInteractor: WalletListLocalStorageSubscriber, WalletListLocalSubscriptionHandler {
    func handleNewProxyWalletsUpdate(result: Result<Int, Error>) {
        switch result {
        case let .success(count):
            presenter?.didReceiveWalletsState(hasUpdates: count > 0)
        case let .failure(error):
            logger.error("Unexpected new proxy wallets update error: \(error)")
        }
    }
}
