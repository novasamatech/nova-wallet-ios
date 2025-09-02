import Foundation
import Operation_iOS

private typealias DAppBrowserTabsObservable = Observable<ObservableInMemoryCache<UUID, DAppBrowserTab>>

final class DAppBrowserTabManager {
    let tabsSubscriptionFactory: PersistentTabLocalSubscriptionFactoryProtocol
    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol

    private let fileRepository: WebViewRenderFilesOperationFactoryProtocol
    private let repository: AnyDataProviderRepository<DAppBrowserTab.PersistenceModel>
    private let operationQueue: OperationQueue
    private let observerQueue: DispatchQueue

    private let logger: LoggerProtocol

    private var metaAccount: MetaAccountModel?

    private var browserTabProvider: StreamableProvider<DAppBrowserTab.PersistenceModel>?
    private var selectedWalletProvider: StreamableProvider<ManagedMetaAccountModel>?

    private var transportStates: InMemoryCache<UUID, [DAppTransportState]> = .init()
    private var observableTabs: DAppBrowserTabsObservable = .init(state: .init())

    init(
        fileRepository: WebViewRenderFilesOperationFactoryProtocol,
        tabsSubscriptionFactory: PersistentTabLocalSubscriptionFactoryProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        repository: AnyDataProviderRepository<DAppBrowserTab.PersistenceModel>,
        observerQueue: DispatchQueue = .main,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.repository = repository
        self.tabsSubscriptionFactory = tabsSubscriptionFactory
        self.walletListLocalSubscriptionFactory = walletListLocalSubscriptionFactory
        self.fileRepository = fileRepository
        self.operationQueue = operationQueue
        self.observerQueue = observerQueue
        self.logger = logger

        setup()
    }
}

// MARK: Private

private extension DAppBrowserTabManager {
    func setup() {
        selectedWalletProvider = subscribeSelectedWalletProvider()
    }

    func clearInMemory() {
        transportStates = .init()
        observableTabs.state.removeAllValues()
    }

    func saveRenderWrapper(
        renderData: Data?,
        tabId: UUID
    ) -> CompoundOperationWrapper<Void> {
        if let renderData {
            fileRepository.saveRenderOperation(for: tabId, data: { renderData })
        } else {
            fileRepository.removeRender(for: tabId)
        }
    }

    func saveWrapper(for tab: DAppBrowserTab) -> CompoundOperationWrapper<DAppBrowserTab> {
        let persistenceModel = tab.persistenceModel

        let saveTabOperation = repository.saveOperation(
            { [persistenceModel] },
            { [] }
        )

        let resultOperation: BaseOperation<DAppBrowserTab> = ClosureOperation {
            _ = try saveTabOperation.extractNoCancellableResultData()

            return tab
        }

        resultOperation.addDependency(saveTabOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: [saveTabOperation]
        )
    }

    func saveTransportsState(for tab: DAppBrowserTab) {
        if let states = tab.transportStates {
            transportStates.store(value: states, for: tab.uuid)
        } else {
            transportStates.removeValue(for: tab.uuid)
        }
    }

    func retrieveWrapper(for tabId: UUID) -> CompoundOperationWrapper<DAppBrowserTab?> {
        if let currentTab = observableTabs.state.fetchValue(for: tabId) {
            return .createWithResult(currentTab)
        } else {
            let fetchTabOperation = repository.fetchOperation(
                by: { tabId.uuidString },
                options: RepositoryFetchOptions()
            )

            let resultOperation = ClosureOperation<DAppBrowserTab?> { [weak self] in
                guard
                    let self,
                    let fetchResult = try fetchTabOperation.extractNoCancellableResultData()
                else {
                    return nil
                }

                return map(persistenceModel: fetchResult)
            }

            resultOperation.addDependency(fetchTabOperation)

            return CompoundOperationWrapper(
                targetOperation: resultOperation,
                dependencies: [fetchTabOperation]
            )
        }
    }

    func updateRenderWrapper(
        render: DAppBrowserTabRenderProtocol,
        tab: DAppBrowserTab
    ) -> CompoundOperationWrapper<Void> {
        let renderDataOperation = render.serializationOperation()

        let wrapper: CompoundOperationWrapper<Void> = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] in
            guard let self else {
                throw DAppBrowserTabManagerError.renderCacheFailed
            }

            let renderData = try renderDataOperation.extractNoCancellableResultData()

            return saveRenderWrapper(
                renderData: renderData,
                tabId: tab.uuid
            )
        }

        wrapper.addDependency(operations: [renderDataOperation])

        return wrapper.insertingHead(operations: [renderDataOperation])
    }

    func removeWrapper(for tabId: UUID) -> CompoundOperationWrapper<Void> {
        let deleteOperation = repository.saveOperation(
            { [] },
            { [tabId.uuidString] }
        )

        let renderRemoveWrapper = fileRepository.removeRender(for: tabId)
        renderRemoveWrapper.addDependency(operations: [deleteOperation])

        return renderRemoveWrapper.insertingHead(operations: [deleteOperation])
    }

    func removeWrapper(for tabIds: [UUID]) -> CompoundOperationWrapper<Set<UUID>> {
        let rendersClearWrapper = fileRepository.removeRenders(for: tabIds)
        let deleteOperation = repository.saveOperation(
            { [] },
            { tabIds.map(\.uuidString) }
        )

        let mappingOperation = ClosureOperation<Set<UUID>> {
            _ = try rendersClearWrapper.targetOperation.extractNoCancellableResultData()
            _ = try deleteOperation.extractNoCancellableResultData()

            return Set(tabIds)
        }

        mappingOperation.addDependency(rendersClearWrapper.targetOperation)
        mappingOperation.addDependency(deleteOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: rendersClearWrapper.allOperations + [deleteOperation]
        )
    }

    func removeAllWrapper(_ metaIds: Set<MetaAccountModel.Id>?) -> CompoundOperationWrapper<Set<UUID>> {
        let tabsWrapper: CompoundOperationWrapper<[DAppBrowserTab]> = if let metaIds {
            tabsFetchWrapper(for: metaIds)
        } else {
            .createWithResult(
                observableTabs
                    .state
                    .fetchAllValues()
            )
        }

        let wrapper: CompoundOperationWrapper<Set<UUID>> = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                return .createWithError(BaseOperationError.parentOperationCancelled)
            }

            let tabIds = try tabsWrapper.targetOperation.extractNoCancellableResultData().map(\.uuid)

            return removeWrapper(for: tabIds)
        }

        wrapper.addDependency(wrapper: tabsWrapper)

        return wrapper.insertingHead(operations: tabsWrapper.allOperations)
    }

    func tabsFetchWrapper(for metaIds: Set<MetaAccountModel.Id>) -> CompoundOperationWrapper<[DAppBrowserTab]> {
        let fetchTabsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let resultOperaton = ClosureOperation { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let persistedTabs = try fetchTabsOperation.extractNoCancellableResultData()

            let tabs = persistedTabs
                .filter { metaIds.contains($0.metaId) }
                .map { self.map(persistenceModel: $0) }

            return sorted(tabs)
        }

        resultOperaton.addDependency(fetchTabsOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperaton,
            dependencies: [fetchTabsOperation]
        )
    }

    func sorted(_ tabs: [DAppBrowserTab]) -> [DAppBrowserTab] {
        tabs.sorted { $0.createdAt < $1.createdAt }
    }

    func apply(_ tabsChanges: [DataProviderChange<DAppBrowserTab.PersistenceModel>]) {
        var updatedTabs: [UUID: DAppBrowserTab] = observableTabs.state
            .fetchAllValues()
            .reduce(into: [:]) { $0[$1.uuid] = $1 }

        tabsChanges.forEach { change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                let tab = map(persistenceModel: newItem)
                updatedTabs[tab.uuid] = tab
            case let .delete(deletedIdentifier):
                guard let tabId = UUID(uuidString: deletedIdentifier) else { return }

                updatedTabs[tabId] = nil
                transportStates.removeValue(for: tabId)
            }
        }

        observableTabs.state = .init(with: updatedTabs)
    }

    func map(persistenceModel: DAppBrowserTab.PersistenceModel) -> DAppBrowserTab {
        let iconURL: URL? = if let urlString = persistenceModel.icon {
            URL(string: urlString)
        } else {
            nil
        }

        let tab = DAppBrowserTab(
            uuid: persistenceModel.uuid,
            name: persistenceModel.name,
            url: persistenceModel.url,
            metaId: persistenceModel.metaId,
            createdAt: persistenceModel.createdAt,
            renderModifiedAt: persistenceModel.renderModifiedAt,
            transportStates: transportStates.fetchValue(for: persistenceModel.uuid),
            desktopOnly: persistenceModel.desktopOnly,
            icon: iconURL
        )

        return tab
    }
}

// MARK: DAppBrowserTabLocalSubscriber

extension DAppBrowserTabManager: DAppBrowserTabLocalSubscriber, DAppBrowserTabLocalSubscriptionHandler {
    func handleBrowserTabs(
        result: Result<[DataProviderChange<DAppBrowserTab.PersistenceModel>], any Error>
    ) {
        switch result {
        case let .success(changes):
            apply(changes)
        case let .failure(error):
            logger.error("Failed on DAppBrowserTab local subscription with error: \(error.localizedDescription)")
        }
    }
}

// MARK: WalletListLocalStorageSubscriber

extension DAppBrowserTabManager: WalletListLocalStorageSubscriber, WalletListLocalSubscriptionHandler {
    func handleSelectedWallet(
        result: Result<ManagedMetaAccountModel?, any Error>
    ) {
        switch result {
        case let .success(managedMetaAccount):
            guard metaAccount?.metaId != managedMetaAccount?.info.metaId else {
                return
            }

            observableTabs.state.removeAllValues()
            metaAccount = managedMetaAccount?.info

            guard let metaAccount else { return }

            browserTabProvider = subscribeToBrowserTabs(metaAccount.metaId)
        case let .failure(error):
            logger.error("Failed on WalletList local subscription with error: \(error.localizedDescription)")
        }
    }
}

// MARK: DAppBrowserTabManagerProtocol

extension DAppBrowserTabManager: DAppBrowserTabManagerProtocol {
    func retrieveTab(with id: UUID) -> CompoundOperationWrapper<DAppBrowserTab?> {
        retrieveWrapper(for: id)
    }

    func getAllTabs(for metaIds: Set<MetaAccountModel.Id>?) -> CompoundOperationWrapper<[DAppBrowserTab]> {
        if let metaIds {
            return tabsFetchWrapper(for: metaIds)
        } else {
            let currentTabs = observableTabs
                .state
                .fetchAllValues()

            guard currentTabs.isEmpty else {
                return .createWithResult(sorted(currentTabs))
            }

            guard let metaAccount else {
                return .createWithResult([])
            }

            return tabsFetchWrapper(for: [metaAccount.metaId])
        }
    }

    func removeTab(with id: UUID) {
        let wrapper = removeWrapper(for: id)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main,
            callbackClosure: { [weak self] _ in
                self?.transportStates.removeValue(for: id)
            }
        )
    }

    func updateTab(_ tab: DAppBrowserTab) -> CompoundOperationWrapper<DAppBrowserTab> {
        saveTransportsState(for: tab)

        return saveWrapper(for: tab)
    }

    func updateRenderForTab(
        with id: UUID,
        render: DAppBrowserTabRenderProtocol
    ) -> CompoundOperationWrapper<Void> {
        guard let tab = observableTabs.state.fetchValue(for: id) else {
            return .createWithResult(())
        }

        let newTab = tab.updating(renderModifiedAt: Date())

        let updateRenderWrapper = updateRenderWrapper(
            render: render,
            tab: newTab
        )

        var resultWrapper = saveWrapper(
            for: newTab
        )

        resultWrapper.addDependency(wrapper: updateRenderWrapper)

        resultWrapper = resultWrapper.insertingHead(operations: updateRenderWrapper.allOperations)

        let voidResultOperation = ClosureOperation {
            _ = try resultWrapper.targetOperation.extractNoCancellableResultData()
        }

        resultWrapper.allOperations.forEach { voidResultOperation.addDependency($0) }

        return resultWrapper.insertingTail(operation: voidResultOperation)
    }

    func cleanTransport(for tabIds: Set<UUID>) -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            tabIds.forEach { self?.transportStates.removeValue(for: $0) }
        }
    }

    func removeAll(for metaIds: Set<MetaAccountModel.Id>?) {
        let wrapper = removeAllWrapper(metaIds)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.clearInMemory()
            case .failure:
                self?.logger.warning("\(String(describing: self)) Failed on tabs deletion operation")
            }
        }
    }

    func removeAllWrapper(for metaIds: Set<MetaAccountModel.Id>?) -> CompoundOperationWrapper<Set<UUID>> {
        removeAllWrapper(metaIds)
    }

    func addObserver(
        _ observer: DAppBrowserTabsObserver,
        sendOnSubscription: Bool
    ) {
        observableTabs.addObserver(
            with: observer,
            sendStateOnSubscription: sendOnSubscription,
            queue: observerQueue
        ) { [weak self] _, newState in
            guard let self else { return }

            let sortedTabs = sorted(newState.fetchAllValues())

            observer.didReceiveUpdatedTabs(sortedTabs)
        }
    }
}
