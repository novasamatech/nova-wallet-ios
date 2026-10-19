import Foundation

protocol SubtensorStakeStateSourceFactoryProtocol {
    func getSource(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        chainRegistry: ChainRegistryProtocol
    ) -> SubtensorStakeStateSource?
}

final class SubtensorStakeStateSourceFactory {
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var sources: [String: WeakWrapper] = [:]
    private let mutex = NSLock()

    init(eventCenter: EventCenterProtocol, operationQueue: OperationQueue, logger: LoggerProtocol) {
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

extension SubtensorStakeStateSourceFactory: SubtensorStakeStateSourceFactoryProtocol {
    func getSource(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        chainRegistry: ChainRegistryProtocol
    ) -> SubtensorStakeStateSource? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let key = chainAsset.chainAssetId.stringValue + "-" + accountId.toHex()

        if let source = sources[key]?.target as? SubtensorStakeStateSource {
            return source
        }

        let chainId = chainAsset.chain.chainId

        guard
            chainRegistry.getConnection(for: chainId) != nil,
            chainRegistry.getRuntimeProvider(for: chainId) != nil else {
            return nil
        }

        let runtimeConnectionStore = ChainRegistryRuntimeConnectionStore(chainId: chainId, chainRegistry: chainRegistry)

        let apiOperationFactory = SubtensorApiOperationFactory(
            runtimeConnectionStore: runtimeConnectionStore,
            operationQueue: operationQueue
        )

        let source = SubtensorStakeStateSource(
            accountId: accountId,
            chainAssetId: chainAsset.chainAssetId,
            stakeStateFetchOperationFactory: SubtensorStakeStateFetchOperationFactory(
                operationFactory: apiOperationFactory,
                operationQueue: operationQueue
            ),
            runtimeConnectionStore: runtimeConnectionStore,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            workingQueue: DispatchQueue(label: "io.novawallet.subtensor.stakestate.\(UUID().uuidString)"),
            logger: logger
        )

        sources = sources.filter { $0.value.target != nil }
        sources[key] = WeakWrapper(target: source)

        return source
    }
}
