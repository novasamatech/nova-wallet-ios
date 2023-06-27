import Foundation

extension PhishingAccountVerifier {
    static func createSequentialVerifier(
        for storageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared
    ) -> PhishingAccountVerifier {
        let factory = SubstrateRepositoryFactory(storageFacade: storageFacade)
        let repository = factory.createPhishingRepository()
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        return PhishingAccountVerifier(repository: repository, operationQueue: operationQueue)
    }
}
