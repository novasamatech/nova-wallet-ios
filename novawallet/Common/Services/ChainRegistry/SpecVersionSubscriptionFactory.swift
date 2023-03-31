import Foundation
import SubstrateSdk

/**
 *  Protocol is designed to provide methods to create a subscription
 *  for runtime version in a particular chain
 */

protocol SpecVersionSubscriptionFactoryProtocol: AnyObject {
    /**
     *  Creates a subsription for runtime version in particular chain.
     *
     *  - Parameters:
     *      - chain: Chain for which subscription should be created;
     *      - connection: Connection to send request to the chain and receive updates.
     *
     *  - Returns: `SpecVersionSubscriptionProtocol` conforming subscription.
     */
    func createSubscription(
        for chain: ChainModel,
        connection: JSONRPCEngine
    ) -> SpecVersionSubscriptionProtocol
}

/**
 *  Class is designed to implement `SpecVersionSubscriptionFactoryProtocol` in a way to create
 *  `SpecVersionSubscription` subscription.
 */

final class SpecVersionSubscriptionFactory {
    let runtimeSyncService: RuntimeSyncServiceProtocol
    let logger: LoggerProtocol?

    /**
     *  Creates new subscription factory
     *
     *  - Paramaters:
     *      - runtimeSyncService: a sync service that is shared between
     *      subscriptions created by the factory;
     *      - logger: logger to provide info for debugging.
     */
    init(runtimeSyncService: RuntimeSyncServiceProtocol, logger: LoggerProtocol? = nil) {
        self.runtimeSyncService = runtimeSyncService
        self.logger = logger
    }
}

extension SpecVersionSubscriptionFactory: SpecVersionSubscriptionFactoryProtocol {
    func createSubscription(
        for chain: ChainModel,
        connection: JSONRPCEngine
    ) -> SpecVersionSubscriptionProtocol {
        if chain.hasSubstrateRuntime {
            return SpecVersionSubscription(
                chainId: chain.chainId,
                runtimeSyncService: runtimeSyncService,
                connection: connection
            )
        } else {
            return NoRuntimeVersionSubscription(
                chainId: chain.chainId,
                connection: connection,
                logger: logger
            )
        }
    }
}
