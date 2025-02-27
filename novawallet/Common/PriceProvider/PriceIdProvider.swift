import Foundation
import Combine

protocol PriceIdProviderProtocol {
    var priceIdsObservable: Observable<Set<AssetModel.PriceId>> { get }
}

class PriceIdProvider: PriceIdProviderProtocol {
    let chainRegistry: ChainRegistryProtocol
    let queue: DispatchQueue

    let priceIdsObservable: Observable<Set<AssetModel.PriceId>> = .init(state: Set())

    init(
        chainRegistry: ChainRegistryProtocol,
        queue: DispatchQueue = DispatchQueue.global(qos: .utility)
    ) {
        self.chainRegistry = chainRegistry
        self.queue = queue
        subscribe()
    }

    func subscribe() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: queue
        ) { [weak self, chainRegistry] changes in
            guard !changes.isEmpty else {
                return
            }
            let allChains = chainRegistry.availableChainIds?.compactMap {
                chainRegistry.getChain(for: $0)
            } ?? []

            let priceIds = allChains.flatMap { $0.assets.compactMap(\.priceId) }
            self?.priceIdsObservable.state = Set(priceIds)
        }
    }

    deinit {
        chainRegistry.chainsUnsubscribe(self)
    }
}
