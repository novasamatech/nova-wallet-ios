import Foundation
import Operation_iOS

typealias DAppBrowserTabsObservable = Observable<InMemoryCache<UUID, DAppBrowserTab>>

final class DAppBrowserTabManager {
    let tabsSubscriptionFactory: PersistentTabLocalSubscriptionFactoryProtocol

    private let fileRepository: WebViewRenderFilesOperationFactoryProtocol
    private let repository: AnyDataProviderRepository<DAppBrowserTab.PersistenceModel>
    private let operationQueue: OperationQueue
    private let observerQueue: DispatchQueue
    private let eventCenter: EventCenterProtocol

    private let logger: LoggerProtocol

    private var browserTabProvider: StreamableProvider<DAppBrowserTab.PersistenceModel>?

    private var transportStates: InMemoryCache<UUID, [DAppTransportState]> = .init()
    private var observableTabs: DAppBrowserTabsObservable = .init(state: .init())

    init(
        fileRepository: WebViewRenderFilesOperationFactoryProtocol,
        tabsSubscriptionFactory: PersistentTabLocalSubscriptionFactoryProtocol,
        repository: AnyDataProviderRepository<DAppBrowserTab.PersistenceModel>,
        eventCenter: EventCenterProtocol,
        observerQueue: DispatchQueue = .main,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.repository = repository
        self.tabsSubscriptionFactory = tabsSubscriptionFactory
        self.fileRepository = fileRepository
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.observerQueue = observerQueue
        self.logger = logger

        setup()
    }
}

// MARK: Private

private extension DAppBrowserTabManager {
    func setup() {
        eventCenter.add(
            observer: self,
            dispatchIn: .main
        )

        browserTabProvider = subscribeToBrowserTabs(nil)
    }

    func clearInMemory() {
        transportStates = .init()
        observableTabs.state = .init()
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

        let resultOperation = ClosureOperation { [weak self] in
            _ = try saveTabOperation.extractNoCancellableResultData()

            if let transportStates = tab.transportStates {
                self?.transportStates.store(
                    value: transportStates,
                    for: tab.uuid
                )
            } else {
                self?.transportStates.removeValue(for: tab.uuid)
            }

            return tab
        }
        resultOperation.addDependency(saveTabOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: [saveTabOperation]
        )
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

    func removeTabWrapper(for tabId: UUID) -> CompoundOperationWrapper<Void> {
        let deleteOperation = repository.saveOperation(
            { [] },
            { [tabId.uuidString] }
        )

        let renderRemoveWrapper = fileRepository.removeRender(for: tabId)
        renderRemoveWrapper.addDependency(operations: [deleteOperation])

        return renderRemoveWrapper.insertingHead(operations: [deleteOperation])
    }

    func removeAllWrapper() -> CompoundOperationWrapper<Void> {
        let tabIds = observableTabs.state
            .fetchAllValues()
            .map(\.uuid)

        let rendersClearWrapper = fileRepository.removeRenders(for: tabIds)
        let deleteOperation = repository.deleteAllOperation()

        let mappingOperation = ClosureOperation {
            _ = try rendersClearWrapper.targetOperation.extractNoCancellableResultData()
            _ = try deleteOperation.extractNoCancellableResultData()

            return
        }

        mappingOperation.addDependency(rendersClearWrapper.targetOperation)
        mappingOperation.addDependency(deleteOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: rendersClearWrapper.allOperations + [deleteOperation]
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

// MARK: DAppBrowserTabManagerProtocol

extension DAppBrowserTabManager: DAppBrowserTabManagerProtocol {
    func retrieveTab(with id: UUID) -> CompoundOperationWrapper<DAppBrowserTab?> {
        retrieveWrapper(for: id)
    }

    func getAllTabs() -> CompoundOperationWrapper<[DAppBrowserTab]> {
        let currentTabs = observableTabs.state.fetchAllValues()

        guard currentTabs.isEmpty else {
            return .createWithResult(sorted(currentTabs))
        }

        let fetchTabsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let resultOperaton = ClosureOperation { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let persistedTabs = try fetchTabsOperation.extractNoCancellableResultData()

            let tabs = persistedTabs.map { self.map(persistenceModel: $0) }

            return sorted(tabs)
        }

        resultOperaton.addDependency(fetchTabsOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperaton,
            dependencies: [fetchTabsOperation]
        )
    }

    func removeTab(with id: UUID) {
        let wrapper = removeTabWrapper(for: id)

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
        saveWrapper(for: tab)
    }

    func updateRenderForTab(
        with id: UUID,
        render: DAppBrowserTabRenderProtocol
    ) -> CompoundOperationWrapper<Void> {
        guard let tab = observableTabs.state.fetchValue(for: id) else {
            return .createWithResult(())
        }

        let updateRenderWrapper = updateRenderWrapper(
            render: render,
            tab: tab
        )

        var resultWrapper = saveWrapper(
            for: tab.updating(renderModifiedAt: Date())
        )

        resultWrapper.addDependency(wrapper: updateRenderWrapper)

        resultWrapper = resultWrapper.insertingHead(operations: updateRenderWrapper.allOperations)

        let voidResultOperation = ClosureOperation {
            _ = try resultWrapper.targetOperation.extractNoCancellableResultData()
        }

        resultWrapper.allOperations.forEach { voidResultOperation.addDependency($0) }

        return resultWrapper.insertingTail(operation: voidResultOperation)
    }

    func removeAll() {
        let wrapper = removeAllWrapper()

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

// MARK: EventVisitorProtocol

extension DAppBrowserTabManager: EventVisitorProtocol {
    func processSelectedWalletChanged(event _: SelectedWalletSwitched) {
        transportStates.removeAllValues()

        observableTabs.state
            .fetchAllValues()
            .map { $0.clearingTransportStates() }
            .forEach { observableTabs.state.store(value: $0, for: $0.uuid) }
    }
}
