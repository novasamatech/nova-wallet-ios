import Foundation
import RobinHood
import SubstrateSdk

protocol ParaStkYieldBoostProviderFactoryProtocol {
    func getTasksProvider(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) throws -> AnySingleValueProvider<[ParaStkYieldBoostState.Task]>
}

final class ParaStkYieldBoostProviderFactory: ParaStkYieldBoostProviderFactoryProtocol {
    static let shared = ParaStkYieldBoostProviderFactory(
        chainRegistry: ChainRegistryFacade.sharedRegistry,
        storageFacade: SubstrateDataStorageFacade.shared,
        operationQueue: OperationManagerFacade.sharedDefaultQueue
    )

    private var providers: [String: WeakWrapper] = [:]

    let chainRegistry: ChainRegistryProtocol
    let storageFacade: StorageFacadeProtocol
    let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.storageFacade = storageFacade
        self.operationQueue = operationQueue
    }

    private func clearIfNeeded() {
        providers = providers.filter { $0.value.target != nil }
    }

    func getTasksProvider(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) throws -> AnySingleValueProvider<[ParaStkYieldBoostState.Task]> {
        let targetIdentifier = "yield-boost-\(chainId)-\(accountId.toHex())"

        if let provider = providers[targetIdentifier]?.target as? SingleValueProvider<[ParaStkYieldBoostState.Task]> {
            return AnySingleValueProvider(provider)
        }

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let source = ParaStkYieldBoostTasksSource(
            operationFactory: AutomationTimeOperationFactory(requestFactory: storageRequestFactory),
            connection: connection,
            runtimeProvider: runtimeProvider,
            accountId: accountId
        )

        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
            storageFacade.createRepository()

        let trigger: DataProviderEventTrigger = [.onAddObserver, .onInitialization]
        let provider = SingleValueProvider(
            targetIdentifier: targetIdentifier,
            source: AnySingleValueProviderSource(source),
            repository: AnyDataProviderRepository(repository),
            updateTrigger: trigger
        )

        providers[targetIdentifier] = WeakWrapper(target: provider)

        return AnySingleValueProvider(provider)
    }
}
