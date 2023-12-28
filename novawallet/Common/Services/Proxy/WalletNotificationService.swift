import RobinHood

protocol WalletNotificationServiceProtocol {
    var hasUpdatesObservable: Observable<Bool> { get }
    func setup()
}

final class WalletNotificationService: WalletNotificationServiceProtocol {
    let proxyListLocalSubscriptionFactory: ProxyListLocalSubscriptionFactoryProtocol
    let logger: LoggerProtocol

    private var proxyListSubscription: StreamableProvider<ProxyAccountModel>?
    var hasUpdatesObservable: Observable<Bool> = .init(state: false)

    private var proxies: [ProxyAccountModel] = [] {
        didSet {
            if proxies != oldValue {
                hasUpdatesObservable.state = proxies.hasNotActive
            }
        }
    }

    init(
        proxyListLocalSubscriptionFactory: ProxyListLocalSubscriptionFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.proxyListLocalSubscriptionFactory = proxyListLocalSubscriptionFactory
        self.logger = logger
    }

    func setup() {
        proxyListSubscription = subscribeAllProxies()
    }
}

extension WalletNotificationService: ProxyListLocalStorageSubscriber, ProxyListLocalSubscriptionHandler {
    func handleAllProxies(result: Result<[DataProviderChange<ProxyAccountModel>], Error>) {
        switch result {
        case let .success(changes):
            proxies = proxies.applying(changes: changes)
        case let .failure(error):
            logger.error(error.localizedDescription)
        }
    }
}
