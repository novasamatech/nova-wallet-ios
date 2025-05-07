import Operation_iOS

protocol WalletNotificationServiceProtocol: ApplicationServiceProtocol {
    var hasUpdatesObservable: Observable<Bool> { get }
}

final class WalletNotificationService: WalletNotificationServiceProtocol, AnyProviderAutoCleaning {
    let proxyListLocalSubscriptionFactory: ProxyListLocalSubscriptionFactoryProtocol
    let logger: LoggerProtocol

    private var proxyDataProvider: StreamableProvider<ProxyAccountModel>?
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
        proxyDataProvider = subscribeAllProxies()
    }

    func throttle() {
        clear(streamableProvider: &proxyDataProvider)
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
