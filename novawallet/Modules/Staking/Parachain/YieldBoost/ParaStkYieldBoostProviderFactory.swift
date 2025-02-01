import Foundation
import Operation_iOS
import SubstrateSdk

protocol ParaStkYieldBoostProviderFactoryProtocol {
    func getTasksProvider(
        for chainAssetId: ChainAssetId,
        accountId: AccountId
    ) throws -> AnySingleValueProvider<[ParaStkYieldBoostState.Task]>
}

final class ParaStkYieldBoostProviderFactory: ParaStkYieldBoostProviderFactoryProtocol {
    static let shared = ParaStkYieldBoostProviderFactory(
        chainRegistry: ChainRegistryFacade.sharedRegistry,
        storageFacade: SubstrateDataStorageFacade.shared,
        eventCenter: EventCenter.shared,
        operationQueue: OperationManagerFacade.sharedDefaultQueue
    )

    private var providers: [String: WeakWrapper] = [:]

    let chainRegistry: ChainRegistryProtocol
    let storageFacade: StorageFacadeProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.storageFacade = storageFacade
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
    }

    private func clearIfNeeded() {
        providers = providers.filter { $0.value.target != nil }
    }

    func getTasksProvider(
        for chainAssetId: ChainAssetId,
        accountId: AccountId
    ) throws -> AnySingleValueProvider<[ParaStkYieldBoostState.Task]> {
        let targetIdentifier = "yield-boost-\(chainAssetId.stringValue)-\(accountId.toHex())"

        if let provider = providers[targetIdentifier]?.target as? SingleValueProvider<[ParaStkYieldBoostState.Task]> {
            return AnySingleValueProvider(provider)
        }

        let connection = try chainRegistry.getConnectionOrError(for: chainAssetId.chainId)
        let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainAssetId.chainId)

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let wrapperTrigger: DataProviderEventTrigger = [.onInitialization, .onAddObserver]
        let trigger = AccountAssetBalanceTrigger(
            chainAssetId: chainAssetId,
            eventCenter: eventCenter,
            wrappedTrigger: wrapperTrigger,
            accountId: accountId
        )

        let source = ParaStkYieldBoostTasksSource(
            operationFactory: AutomationTimeOperationFactory(requestFactory: storageRequestFactory),
            connection: connection,
            runtimeProvider: runtimeProvider,
            accountId: accountId,
            assetChangeStore: trigger
        )

        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
            storageFacade.createRepository()

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
