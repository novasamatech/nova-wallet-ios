import Foundation
import Operation_iOS

typealias DAppBrowserTabsObservable = Observable<[UUID: DAppBrowserTab]>

final class DAppBrowserTabManager {
    let tabsSubscriptionFactory: PersistentTabLocalSubscriptionFactoryProtocol

    private let fileRepository: WebViewRenderFilesOperationFactoryProtocol
    private let repository: AnyDataProviderRepository<DAppBrowserTab.PersistenceModel>
    private let operationQueue: OperationQueue
    private let observerQueue: DispatchQueue

    private let logger: LoggerProtocol

    private var browserTabProvider: StreamableProvider<DAppBrowserTab.PersistenceModel>?

    private var dAppTransportStates: [UUID: [DAppTransportState]] = [:]

    private var tabs: DAppBrowserTabsObservable = .init(state: [:])

    init(
        fileRepository: WebViewRenderFilesOperationFactoryProtocol,
        tabsSubscriptionFactory: PersistentTabLocalSubscriptionFactoryProtocol,
        repository: AnyDataProviderRepository<DAppBrowserTab.PersistenceModel>,
        observerQueue: DispatchQueue = .main,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.repository = repository
        self.tabsSubscriptionFactory = tabsSubscriptionFactory
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
        browserTabProvider = subscribeToBrowserTabs(nil)
    }

    func clearInMemory() {
        dAppTransportStates = [:]
        tabs.state = [:]
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

            self?.dAppTransportStates[tab.uuid] = tab.transportStates

            return tab
        }
        resultOperation.addDependency(saveTabOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: [saveTabOperation]
        )
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
            lastModified: persistenceModel.lastModified,
            transportStates: dAppTransportStates[persistenceModel.uuid],
            desktopOnly: persistenceModel.desktopOnly,
            icon: iconURL
        )

        return tab
    }

    func retrieveWrapper(for tabId: UUID) -> CompoundOperationWrapper<DAppBrowserTab?> {
        if let currentTab = tabs.state[tabId] {
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
        let tabIds = tabs.state.map(\.value.uuid)

        let rendersClearWrapper = fileRepository.removeRenders(for: tabIds)
        let deleteOperation = repository.deleteAllOperation()

        rendersClearWrapper.addDependency(operations: [deleteOperation])

        return rendersClearWrapper.insertingHead(operations: [deleteOperation])
    }

    func sorted(_ tabs: [DAppBrowserTab]) -> [DAppBrowserTab] {
        tabs.sorted { $0.lastModified < $1.lastModified }
    }

    func apply(_ tabsChanges: [DataProviderChange<DAppBrowserTab.PersistenceModel>]) {
        var updatedTabs = tabs.state

        tabsChanges.forEach { change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                let tab = map(persistenceModel: newItem)
                updatedTabs[tab.uuid] = tab
            case let .delete(deletedIdentifier):
                guard let tabId = UUID(uuidString: deletedIdentifier) else { return }

                updatedTabs[tabId] = nil
                dAppTransportStates[tabId] = nil
            }
        }

        tabs.state = updatedTabs
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
            logger.error("Did fail on DAppBrowserTab local subscription with error: \(error.localizedDescription)")
        }
    }
}

// MARK: DAppBrowserTabManagerProtocol

extension DAppBrowserTabManager: DAppBrowserTabManagerProtocol {
    func retrieveTab(with id: UUID) -> CompoundOperationWrapper<DAppBrowserTab?> {
        retrieveWrapper(for: id)
    }

    func getAllTabs() -> CompoundOperationWrapper<[DAppBrowserTab]> {
        let currentTabs = Array(tabs.state.values)

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
                self?.dAppTransportStates[id] = nil
            }
        )
    }

    func updateTab(_ tab: DAppBrowserTab) -> CompoundOperationWrapper<DAppBrowserTab> {
        saveWrapper(for: tab)
    }

    func updateRenderForTab(
        with id: UUID,
        renderer: DAppBrowserTabRendererProtocol
    ) -> CompoundOperationWrapper<Void> {
        let renderDataWrapper = renderer.renderDataWrapper(using: operationQueue)

        return OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let renderData = try renderDataWrapper.targetOperation.extractNoCancellableResultData()

            return saveRenderWrapper(
                renderData: renderData,
                tabId: id
            )
        }
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

    func addObserver(_ observer: DAppBrowserTabsObserver) {
        tabs.addObserver(with: observer, queue: observerQueue) { [weak self] _, newState in
            guard let self else { return }

            let sortedTabs = sorted(Array(newState.values))

            observer.didReceiveUpdatedTabs(sortedTabs)
        }
    }
}

// MARK: Singleton

extension DAppBrowserTabManager {
    static let shared: DAppBrowserTabManager = {
        let mapper = DAppBrowserTabMapper()
        let storageFacade = UserDataStorageFacade.shared

        let coreDataRepository = storageFacade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let renderFilesRepository = WebViewRenderFilesOperationFactory(
            repository: FileRepository(),
            directoryPath: ApplicationConfig.shared.webPageRenderCachePath
        )

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let logger = Logger.shared

        return DAppBrowserTabManager(
            fileRepository: renderFilesRepository,
            tabsSubscriptionFactory: PersistentTabLocalSubscriptionFactory(
                storageFacade: storageFacade,
                operationQueue: operationQueue,
                logger: logger
            ),
            repository: AnyDataProviderRepository(coreDataRepository),
            operationQueue: operationQueue,
            logger: logger
        )
    }()
}
