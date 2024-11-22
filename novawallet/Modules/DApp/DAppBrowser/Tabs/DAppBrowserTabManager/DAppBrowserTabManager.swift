import Foundation
import Operation_iOS

final class DAppBrowserTabManager {
    private let cacheBasePath: String
    private let fileRepository: WebViewRenderFilesOperationFactoryProtocol
    private let repository: CoreDataRepository<DAppBrowserTab.PersistenceModel, CDDAppBrowserTab>
    private let operationQueue: OperationQueue
    private let observerQueue: DispatchQueue

    private let logger: LoggerProtocol

    private var dAppTransportStates: [UUID: [DAppTransportState]] = [:]
    private var tabs: [UUID: DAppBrowserTab] = [:]
    private var observers: [WeakWrapper] = []

    init(
        cacheBasePath: String,
        fileRepository: WebViewRenderFilesOperationFactoryProtocol,
        repository: CoreDataRepository<DAppBrowserTab.PersistenceModel, CDDAppBrowserTab>,
        observerQueue: DispatchQueue = .main,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.cacheBasePath = cacheBasePath
        self.repository = repository
        self.fileRepository = fileRepository
        self.operationQueue = operationQueue
        self.observerQueue = observerQueue
        self.logger = logger
    }
}

// MARK: Private

private extension DAppBrowserTabManager {
    func clearObservers() {
        observers = observers.filter { $0.target != nil }
    }

    func clearInMemory() {
        dAppTransportStates = [:]
        tabs = [:]
    }

    func notifyObservers() {
        let tabs = Array(self.tabs.values)

        observerQueue.async {
            self.observers.forEach { weakWrapper in
                guard let observer = weakWrapper.target as? DAppBrowserTabsObserver else {
                    return
                }

                observer.didReceiveUpdatedTabs(tabs)
            }
        }
    }

    func saveWrapper(for tab: DAppBrowserTab) -> CompoundOperationWrapper<DAppBrowserTab> {
        let persistenceModel = tab.persistenceModel

        let saveTabOperation = repository.saveOperation(
            { [persistenceModel] },
            { [] }
        )

        let saveRenderWrapper: CompoundOperationWrapper<Void> = if let renderData = tab.stateRender {
            fileRepository.saveRenderOperation(for: tab.uuid, data: { renderData })
        } else {
            fileRepository.removeRender(for: tab.uuid)
        }

        let resultOperation = ClosureOperation { [weak self] in
            _ = try saveTabOperation.extractNoCancellableResultData()
            _ = try saveRenderWrapper.targetOperation.extractNoCancellableResultData()

            self?.tabs[tab.uuid] = tab
            self?.dAppTransportStates[tab.uuid] = tab.transportStates

            self?.notifyObservers()

            return tab
        }
        resultOperation.addDependency(saveTabOperation)
        resultOperation.addDependency(saveRenderWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: [saveTabOperation] + saveRenderWrapper.allOperations
        )
    }

    func retrieveWrapper(for tabId: UUID) -> CompoundOperationWrapper<DAppBrowserTab?> {
        if let currentTab = tabs[tabId] {
            return .createWithResult(currentTab)
        } else {
            let fetchTabOperation = repository.fetchOperation(
                by: { tabId.uuidString },
                options: RepositoryFetchOptions()
            )

            let fetchRenderWrapper = fileRepository.fetchRender(for: tabId)

            let resultOperation = ClosureOperation<DAppBrowserTab?> { [weak self] in
                guard let fetchResult = try fetchTabOperation.extractNoCancellableResultData() else {
                    return nil
                }

                let iconURL: URL? = if let urlString = fetchResult.icon {
                    URL(string: urlString)
                } else {
                    nil
                }

                let render = try fetchRenderWrapper.targetOperation.extractNoCancellableResultData()

                let tab = DAppBrowserTab(
                    uuid: fetchResult.uuid,
                    name: fetchResult.name,
                    url: fetchResult.url,
                    lastModified: fetchResult.lastModified,
                    transportStates: self?.dAppTransportStates[fetchResult.uuid],
                    stateRender: render,
                    desktopOnly: fetchResult.desktopOnly,
                    icon: iconURL
                )

                self?.tabs[tab.uuid] = tab

                return tab
            }
            resultOperation.addDependency(fetchTabOperation)
            resultOperation.addDependency(fetchRenderWrapper.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: resultOperation,
                dependencies: [fetchTabOperation] + fetchRenderWrapper.allOperations
            )
        }
    }

    func createFetchAllRendersWrapper(
        using fetchAllOperation: BaseOperation<[DAppBrowserTab.PersistenceModel]>
    ) -> CompoundOperationWrapper<[UUID: Data]> {
        let fetchRendersWrapper: CompoundOperationWrapper<[UUID: Data]>
        fetchRendersWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] in
            guard let self else {
                return .createWithError(BaseOperationError.parentOperationCancelled)
            }

            let tabs = try fetchAllOperation.extractNoCancellableResultData()

            let fetchRenderOperations: [UUID: CompoundOperationWrapper<Data?>] = tabs.reduce(into: [:]) { acc, tab in
                acc[tab.uuid] = self.fileRepository.fetchRender(for: tab.uuid)
            }

            return createRendersMappingWrapper(using: fetchRenderOperations)
        }

        fetchRendersWrapper.addDependency(operations: [fetchAllOperation])

        return fetchRendersWrapper.insertingHead(operations: [fetchAllOperation])
    }

    func createRendersMappingWrapper(
        using fetchWrappers: [UUID: CompoundOperationWrapper<Data?>]
    ) -> CompoundOperationWrapper<[UUID: Data]> {
        let resultWrapper: CompoundOperationWrapper<[UUID: Data]>
        resultWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let result = try fetchWrappers.reduce(into: [UUID: Data]()) { acc, wrapper in
                let result = try wrapper.value.targetOperation.extractNoCancellableResultData()
                acc[wrapper.key] = result
            }

            return .createWithResult(result)
        }

        let operations = Array(fetchWrappers.values).flatMap(\.allOperations)

        resultWrapper.addDependency(operations: operations)

        return resultWrapper.insertingHead(operations: operations)
    }

    func removeTabWrapper(for tabId: UUID) -> CompoundOperationWrapper<Void> {
        let deleteOperation = repository.saveOperation(
            { [] },
            { [tabId.uuidString] }
        )

        let renderRemoveWrapper = fileRepository.removeRender(for: tabId)
        renderRemoveWrapper.addDependency(operations: [deleteOperation])

        return renderRemoveWrapper
    }

    func removeAllWrapper() -> CompoundOperationWrapper<Void> {
        let tabIds = tabs.map(\.value.uuid)

        let rendersClearWrapper = fileRepository.removeRenders(for: tabIds)
        let deleteOperation = repository.deleteAllOperation()

        rendersClearWrapper.addDependency(operations: [deleteOperation])

        return rendersClearWrapper.insertingHead(operations: [deleteOperation])
    }

    func sorted(_ tabs: [DAppBrowserTab]) -> [DAppBrowserTab] {
        tabs.sorted { $0.lastModified < $1.lastModified }
    }
}

// MARK: DAppBrowserTabManagerProtocol

extension DAppBrowserTabManager: DAppBrowserTabManagerProtocol {
    func retrieveTab(with id: UUID) -> CompoundOperationWrapper<DAppBrowserTab?> {
        retrieveWrapper(for: id)
    }

    func getAllTabs() -> CompoundOperationWrapper<[DAppBrowserTab]> {
        let currentTabs = Array(tabs.values)

        guard currentTabs.isEmpty else {
            return .createWithResult(sorted(currentTabs))
        }

        let fetchTabsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        let fetchRendersWrapper = createFetchAllRendersWrapper(using: fetchTabsOperation)

        let resultOperaton = ClosureOperation { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let persistedTabs = try fetchTabsOperation.extractNoCancellableResultData()
            let renders = try fetchRendersWrapper.targetOperation.extractNoCancellableResultData()

            let tabs = persistedTabs.map { persistenceModel in
                let iconURL: URL? = if let urlString = persistenceModel.icon {
                    URL(string: urlString)
                } else {
                    nil
                }

                return DAppBrowserTab(
                    uuid: persistenceModel.uuid,
                    name: persistenceModel.name,
                    url: persistenceModel.url,
                    lastModified: persistenceModel.lastModified,
                    transportStates: self.dAppTransportStates[persistenceModel.uuid],
                    stateRender: renders[persistenceModel.uuid],
                    desktopOnly: persistenceModel.desktopOnly,
                    icon: iconURL
                )
            }

            tabs.forEach { self.tabs[$0.uuid] = $0 }

            return sorted(tabs)
        }

        resultOperaton.addDependency(fetchRendersWrapper.targetOperation)

        return fetchRendersWrapper.insertingTail(operation: resultOperaton)
    }

    func removeTab(with id: UUID) {
        let wrapper = removeTabWrapper(for: id)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main,
            callbackClosure: { [weak self] _ in
                self?.tabs[id] = nil
                self?.dAppTransportStates[id] = nil
                self?.notifyObservers()
            }
        )
    }

    func updateTab(_ tab: DAppBrowserTab) -> CompoundOperationWrapper<DAppBrowserTab> {
        saveWrapper(for: tab)
    }

    func updateRenderForTab(
        with id: UUID,
        render: Data?
    ) -> CompoundOperationWrapper<DAppBrowserTab> {
        let tabFetchWrapper = retrieveWrapper(for: id)

        let updateWrapper: CompoundOperationWrapper<DAppBrowserTab>
        updateWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] in
            guard
                let self,
                let tab = try tabFetchWrapper.targetOperation.extractNoCancellableResultData()
            else {
                return .createWithError(DAppBrowserTabManagerError.tabNotPersisted)
            }

            return saveWrapper(for: tab.updating(stateRender: render))
        }
        updateWrapper.addDependency(wrapper: tabFetchWrapper)

        return updateWrapper.insertingHead(operations: tabFetchWrapper.allOperations)
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
                self?.notifyObservers()
            case .failure:
                self?.logger.warning("\(String(describing: self)) Failed on tabs deletion operation")
            }
        }
    }

    func addObserver(_ observer: DAppBrowserTabsObserver) {
        clearObservers()

        guard !observers.contains(where: { $0.target === observer }) else {
            return
        }

        observers.append(WeakWrapper(target: observer))
    }
}

// MARK: Singleton

extension DAppBrowserTabManager {
    static let shared: DAppBrowserTabManager = {
        let mapper = DAppBrowserTabMapper()
        let coreDataRepository = UserDataStorageFacade.shared.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let renderFilesRepository = RuntimeFilesOperationFactory(
            repository: FileRepository(),
            directoryPath: ApplicationConfig.shared.webPageRenderCachePath
        )

        return DAppBrowserTabManager(
            cacheBasePath: ApplicationConfig.shared.fileCachePath,
            fileRepository: renderFilesRepository,
            repository: coreDataRepository,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
    }()
}
