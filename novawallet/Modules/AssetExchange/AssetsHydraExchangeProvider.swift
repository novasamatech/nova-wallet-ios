import Foundation
import Operation_iOS

final class AssetsHydraExchangeProvider {
    let chainRegistry: ChainRegistryProtocol

    private var supportedChains: [ChainModel.Id: ChainModel]?
    let syncQueue: DispatchQueue
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.logger = logger

        syncQueue = DispatchQueue(label: "io.novawallet.hydraexchangeprovider.\(UUID().uuidString)")
    }

    private func provideExchanges(
        notifingIn queue: DispatchQueue,
        onChange: @escaping ([AssetsExchangeProtocol]) -> Void
    ) {
        guard let supportedChains else {
            return
        }

        let exchanges: [AssetsExchangeProtocol] = supportedChains.values.flatMap { chain in
            guard
                let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId),
                let connection = chainRegistry.getConnection(for: chain.chainId) else {
                logger.warning("Connection or runtime unavailable for \(chain.name)")
                return [AssetsExchangeProtocol]()
            }

            let omnipoolExchange = AssetsHydraOmnipoolExchange(
                chain: chain,
                runtimeService: runtimeService,
                connection: connection,
                operationQueue: operationQueue
            )

            let stableswapExchange = AssetsHydraStableSwapExchange(
                chain: chain,
                runtimeService: runtimeService,
                connection: connection,
                operationQueue: operationQueue
            )

            let xykExchange = AssetsHydraXYKExchange(
                chain: chain,
                runtimeService: runtimeService,
                connection: connection,
                operationQueue: operationQueue
            )

            return [omnipoolExchange, stableswapExchange, xykExchange]
        }

        dispatchInQueueWhenPossible(queue) {
            onChange(exchanges)
        }
    }

    private func handleChains(changes: [DataProviderChange<ChainModel>]) -> Bool {
        let updatedChains = changes.reduce(into: supportedChains ?? [:]) { accum, change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                accum[newItem.chainId] = newItem.hasSwapHydra ? newItem : nil
            case let .delete(deletedIdentifier):
                accum[deletedIdentifier] = nil
            }
        }

        guard supportedChains != updatedChains else {
            return false
        }

        supportedChains = updatedChains

        return true
    }
}

extension AssetsHydraExchangeProvider: AssetsExchangeProviding {
    func provide(notifingIn queue: DispatchQueue, onChange: @escaping ([AssetsExchangeProtocol]) -> Void) {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: syncQueue,
            filterStrategy: nil
        ) { [weak self] changes in
            guard let self, handleChains(changes: changes) else {
                return
            }

            provideExchanges(notifingIn: queue, onChange: onChange)
        }
    }

    func stop() {
        chainRegistry.chainsUnsubscribe(self)
    }
}
