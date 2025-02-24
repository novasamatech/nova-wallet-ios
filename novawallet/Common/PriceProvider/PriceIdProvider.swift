import Foundation
import Combine

protocol PriceIdProviderProtocol {
    var priceIds: AnyPublisher<Set<AssetModel.PriceId>, Never> { get }
}

class PriceIdProvider: PriceIdProviderProtocol {
    let chainRegistry: ChainRegistryProtocol
    let queue: DispatchQueue

    private let priceIdsSubject = CurrentValueSubject<Set<AssetModel.PriceId>, Never>([])
    var priceIds: AnyPublisher<Set<AssetModel.PriceId>, Never> {
        priceIdsSubject.eraseToAnyPublisher()
    }

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
            self?.priceIdsSubject.send(Set(priceIds))
        }
    }

    deinit {
        chainRegistry.chainsUnsubscribe(self)
    }
}
