import Foundation
@testable import novawallet

extension ChainRegistryFacade {
    static func setupForIntegrationTest(
        with storageFacade: StorageFacadeProtocol
    ) -> ChainRegistryProtocol {
        let chainRegistry = ChainRegistryFactory.createDefaultRegistry(from: storageFacade)
        chainRegistry.syncUp()

        let target = NSObject()

        let semaphore = DispatchSemaphore(value: 0)
        chainRegistry.chainsSubscribe(
            target, runningInQueue: .global()
        ) { changes in
            if !changes.isEmpty {
                semaphore.signal()
            }
        }

        semaphore.wait()

        chainRegistry.chainsUnsubscribe(target)

        return chainRegistry
    }
}
