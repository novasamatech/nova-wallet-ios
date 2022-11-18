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
    let serviceFactory: EvmBalanceUpdateServiceFactoryProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol

    private let mutex = NSLock()

    private var subscriptions: [String: Active] = [:]

    init(
        chainRegistry: ChainRegistryProtocol,
        serviceFactory: EvmBalanceUpdateServiceFactoryProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.serviceFactory = serviceFactory
        self.operationManager = operationManager
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
                serviceFactory: serviceFactory,
                connection: connection,
                logger: logger
            )
            try container.start()
        }

        subscriptions[cacheKey] = Active(subscriptionIds: [subscriptionId], container: container)

        return subscriptionId
    }
}
