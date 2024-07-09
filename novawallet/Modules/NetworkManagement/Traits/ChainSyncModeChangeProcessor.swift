import Foundation
import Operation_iOS

protocol ChainSyncModeChangeProcessor: AnyObject {
    var chainRegistry: ChainRegistryProtocol { get }

    func handle(_ syncModeChange: DataProviderChange<ChainModel>)
}

extension ChainSyncModeChangeProcessor {
    func observeChainsSyncModeChanges(on queue: DispatchQueue) {
        chainSyncModeChangeVisitor.addObserver(self, on: queue)
    }

    func processSyncModeChange(event: NetworkEnabledChanged) {
        guard let chain = chainRegistry.getChain(for: event.chainId) else {
            return
        }

        let change: DataProviderChange<ChainModel> = event.enabled
            ? .insert(newItem: chain)
            : .delete(deletedIdentifier: chain.chainId)

        handle(change)
    }
}

private extension ChainSyncModeChangeProcessor {
    var chainSyncModeChangeVisitor: ChainSyncModeChangeVisitor { ChainSyncModeChangeVisitor.shared }
}

class ChainSyncModeChangeVisitor: EventVisitorProtocol {
    private let eventCenter: EventCenterProtocol

    private var processors: [(processor: WeakWrapper, queue: DispatchQueue)] = []

    private let mutex = NSLock()

    init(eventCenter: EventCenterProtocol) {
        self.eventCenter = eventCenter

        eventCenter.add(observer: self, dispatchIn: .main)
    }

    static let shared = ChainSyncModeChangeVisitor(eventCenter: EventCenter.shared)

    func addObserver(
        _ observer: ChainSyncModeChangeProcessor,
        on queue: DispatchQueue
    ) {
        mutex.lock()

        processors.append((WeakWrapper(target: observer), queue))

        mutex.unlock()
    }

    func processNetworkEnableChanged(event: NetworkEnabledChanged) {
        processors.forEach { weakWrapper, queue in
            if let processor = weakWrapper.target as? ChainSyncModeChangeProcessor {
                queue.async { processor.processSyncModeChange(event: event) }
            }
        }
    }
}
