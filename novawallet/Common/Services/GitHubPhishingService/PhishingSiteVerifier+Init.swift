import Foundation

extension PhishingSiteVerifier {
    static func createSequentialVerifier(
        for storageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared
    ) -> PhishingSiteVerifier {
        let factory = SubstrateRepositoryFactory(storageFacade: storageFacade)
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        return PhishingSiteVerifier(
            forbiddenTopLevelDomains: ApplicationConfig.shared.phishingDAppsTopLevelSet,
            repositoryFactory: factory,
            operationQueue: operationQueue
        )
    }
}
