import Foundation
import Operation_iOS
import SubstrateSdk

protocol MultisigEventsUpdatingServiceProtocol {
    var subscribedChainIds: Set<ChainModel.Id> { get }

    func setupSubscription(
        for chainId: ChainModel.Id,
        subscriber: MultisigEventsSubscriber
    )

    func clearSubscription(for chainId: ChainModel.Id)

    func clearAllSubscriptions()
}

final class MultisigEventsUpdatingService {
    private let chainRegistry: ChainRegistryProtocol
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue

    private var eventsSubscriptions: [ChainModel.Id: MultisigEventsSubscription] = [:]

    init(
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = DispatchQueue(label: "com.nova.wallet.multisig.events.updating.service")
    ) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
    }
}

extension MultisigEventsUpdatingService: MultisigEventsUpdatingServiceProtocol {
    var subscribedChainIds: Set<ChainModel.Id> {
        Set(eventsSubscriptions.keys)
    }

    func setupSubscription(
        for chainId: ChainModel.Id,
        subscriber: MultisigEventsSubscriber
    ) {
        let subscription = MultisigEventsSubscription(
            chainId: chainId,
            chainRegistry: chainRegistry,
            subscriber: subscriber,
            operationQueue: operationQueue,
            workingQueue: workingQueue
        )

        eventsSubscriptions[chainId] = subscription
    }

    func clearSubscription(for chainId: ChainModel.Id) {
        eventsSubscriptions[chainId] = nil
    }

    func clearAllSubscriptions() {
        eventsSubscriptions.removeAll()
    }
}
