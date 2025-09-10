import Foundation
@testable import novawallet
import Operation_iOS
import Cuckoo

extension MockChainRegistryProtocol {
    func applyDefault(for chains: Set<ChainModel>) -> MockChainRegistryProtocol {
        stub(self) { stub in
            let availableChains = chains
                .reduce(into: [ChainModel.Id: ChainModel]()) { $0[$1.chainId] = $1 }

            let availableChainIds = Set(chains.map(\.chainId))
            stub.availableChainIds.get.thenReturn(availableChainIds)

            stub.getConnection(for: any()).then { chainId in
                if availableChainIds.contains(chainId) {
                    return MockConnection()
                } else {
                    return nil
                }
            }

            stub.getRuntimeProvider(for: any()).then { chainId in
                if availableChainIds.contains(chainId) {
                    return MockRuntimeProviderProtocol().applyDefault(for: chainId)
                } else {
                    return nil
                }
            }

            stub.getChain(for: any()).then { chainId in
                availableChains[chainId]
            }

            stub.chainsSubscribe(
                any(),
                runningInQueue: any(),
                filterStrategy: any(),
                updateClosure: any()
            ).then { _, queue, filterStrategy, closure in
                queue.async {
                    let changes = chains.map { DataProviderChange.insert(newItem: $0) }

                    let filteredChanges = if let filterStrategy {
                        filterStrategy.filter(changes, using: availableChains)
                    } else {
                        changes
                    }

                    closure(filteredChanges)
                }
            }

            stub.chainsUnsubscribe(any()).thenDoNothing()
            stub.syncUp().thenDoNothing()
        }

        return self
    }
}
