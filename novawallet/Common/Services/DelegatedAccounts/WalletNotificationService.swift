import Operation_iOS

protocol WalletNotificationServiceProtocol: ApplicationServiceProtocol {
    var hasUpdatesObservable: Observable<Bool> { get }
}

final class WalletNotificationService: WalletNotificationServiceProtocol, AnyProviderAutoCleaning {
    let proxyListLocalSubscriptionFactory: ProxyListLocalSubscriptionFactoryProtocol
    let multisigListLocalSubscriptionFactory: MultisigListLocalSubscriptionFactoryProtocol
    let logger: LoggerProtocol

    private var proxyDataProvider: StreamableProvider<DelegatedAccount.ProxyAccountModel>?
    private var multisigDataProvider: StreamableProvider<DelegatedAccount.MultisigAccountModel>?
    var hasUpdatesObservable: Observable<Bool> = .init(state: false)

    private var proxies: [DelegatedAccount.ProxyAccountModel] = [] {
        didSet {
            if proxies != oldValue {
                updateHasUpdatesState()
            }
        }
    }

    private var multisigs: [DelegatedAccount.MultisigAccountModel] = [] {
        didSet {
            if multisigs != oldValue {
                updateHasUpdatesState()
            }
        }
    }

    init(
        proxyListLocalSubscriptionFactory: ProxyListLocalSubscriptionFactoryProtocol,
        multisigListLocalSubscriptionFactory: MultisigListLocalSubscriptionFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.proxyListLocalSubscriptionFactory = proxyListLocalSubscriptionFactory
        self.multisigListLocalSubscriptionFactory = multisigListLocalSubscriptionFactory
        self.logger = logger
    }

    private func updateHasUpdatesState() {
        let hasProxyUpdates = proxies.hasNotActive
        let hasMultisigUpdates = multisigs.hasNotActive
        hasUpdatesObservable.state = hasProxyUpdates || hasMultisigUpdates
    }

    func setup() {
        proxyDataProvider = subscribeAllProxies()
        multisigDataProvider = subscribeAllMultisigs()
    }

    func throttle() {
        clear(streamableProvider: &proxyDataProvider)
        clear(streamableProvider: &multisigDataProvider)
    }
}

extension WalletNotificationService: ProxyListLocalStorageSubscriber, ProxyListLocalSubscriptionHandler {
    func handleAllProxies(result: Result<[DataProviderChange<DelegatedAccount.ProxyAccountModel>], Error>) {
        switch result {
        case let .success(changes):
            proxies = proxies.applying(changes: changes)
        case let .failure(error):
            logger.error(error.localizedDescription)
        }
    }
}

extension WalletNotificationService: MultisigListLocalStorageSubscriber, MultisigListLocalSubscriptionHandler {
    func handleAllMultisigs(result: Result<[DataProviderChange<DelegatedAccount.MultisigAccountModel>], Error>) {
        switch result {
        case let .success(changes):
            multisigs = multisigs.applying(changes: changes)
        case let .failure(error):
            logger.error(error.localizedDescription)
        }
    }
}
