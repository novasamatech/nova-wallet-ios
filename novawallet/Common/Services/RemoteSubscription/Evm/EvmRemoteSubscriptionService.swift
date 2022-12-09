import Foundation
import RobinHood

class EvmRemoteSubscriptionService {
    class Active {
        var subscriptionIds: Set<UUID>
        let container: EvmRemoteSubscriptionProtocol

        init(subscriptionIds: Set<UUID>, container: EvmRemoteSubscriptionProtocol) {
            self.subscriptionIds = subscriptionIds
            self.container = container
        }
    }

    let chainRegistry: ChainRegistryProtocol
    let balanceUpdateServiceFactory: EvmBalanceUpdateServiceFactoryProtocol
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol

    private let mutex = NSLock()

    private var subscriptions: [String: Active] = [:]

    init(
        chainRegistry: ChainRegistryProtocol,
        balanceUpdateServiceFactory: EvmBalanceUpdateServiceFactoryProtocol,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.balanceUpdateServiceFactory = balanceUpdateServiceFactory
        self.eventCenter = eventCenter
        self.logger = logger
    }

    func attachToSubscription(
        on chainId: ChainModel.Id,
        request: EvmRemoteSubscriptionRequest,
        cacheKey: String,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) throws -> UUID {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let subscriptionId = UUID()

        if let active = subscriptions[cacheKey] {
            active.subscriptionIds.insert(subscriptionId)

            callbackClosureIfProvided(closure, queue: queue, result: .success(()))

            return subscriptionId
        }

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        let container: EvmRemoteSubscriptionProtocol

        switch request {
        case let .erc20Balace(params):
            container = ERC20SubscriptionManager(
                chainId: chainId,
                params: params,
                serviceFactory: balanceUpdateServiceFactory,
                connection: connection,
                eventCenter: eventCenter,
                logger: logger
            )
            try container.start()
        }

        subscriptions[cacheKey] = Active(subscriptionIds: [subscriptionId], container: container)

        return subscriptionId
    }

    func detachFromSubscription(
        _ cacheKey: String,
        subscriptionId: UUID,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let active = subscriptions[cacheKey] {
            active.subscriptionIds.remove(subscriptionId)

            if active.subscriptionIds.isEmpty {
                subscriptions[cacheKey] = nil
            }

            callbackClosureIfProvided(closure, queue: queue ?? .main, result: .success(()))
        } else {
            callbackClosureIfProvided(closure, queue: queue ?? .main, result: .success(()))
        }
    }
}
