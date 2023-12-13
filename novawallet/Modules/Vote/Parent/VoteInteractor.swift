import Foundation
import RobinHood

final class VoteInteractor {
    weak var presenter: VoteInteractorOutputProtocol?

    let walletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let proxyListLocalSubscriptionFactory: ProxyListLocalSubscriptionFactoryProtocol
    let logger: LoggerProtocol
    private var proxyListSubscription: StreamableProvider<ProxyAccountModel>?
    private var proxies: [ProxyAccountModel] = []

    init(
        walletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        proxyListLocalSubscriptionFactory: ProxyListLocalSubscriptionFactoryProtocol,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.walletSettings = walletSettings
        self.eventCenter = eventCenter
        self.proxyListLocalSubscriptionFactory = proxyListLocalSubscriptionFactory
        self.logger = logger
    }

    private func provideSelectedWallet() {
        guard let selectedWallet = walletSettings.value else {
            return
        }

        presenter?.didReceiveWallet(selectedWallet)
    }

    private func provideWalletUpdates() {
        presenter?.didReceiveWalletsState(hasUpdates: proxies.hasNotActive)
    }
}

extension VoteInteractor: VoteInteractorInputProtocol {
    func setup() {
        provideSelectedWallet()

        eventCenter.add(observer: self, dispatchIn: .main)
        proxyListSubscription = subscribeAllProxies()
        provideWalletUpdates()
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

extension VoteInteractor: ProxyListLocalStorageSubscriber, ProxyListLocalSubscriptionHandler {
    func handleAllProxies(result: Result<[DataProviderChange<ProxyAccountModel>], Error>) {
        switch result {
        case let .success(changes):
            proxies = proxies.applying(changes: changes)
            provideWalletUpdates()
        case let .failure(error):
            logger.error(error.localizedDescription)
        }
    }
}
