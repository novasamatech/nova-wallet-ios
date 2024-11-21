import Foundation
import Operation_iOS

protocol DAppBrowserTabsObserver: AnyObject {
    func didReceiveUpdatedTabs(_ tabs: [DAppBrowserTab])
}

protocol DAppBrowserTabManagerProtocol {
    func retrieveTab(with id: UUID) -> CompoundOperationWrapper<DAppBrowserTab?>
    func getAllTabs() -> CompoundOperationWrapper<[DAppBrowserTab]>

    func updateTab(_ tab: DAppBrowserTab) -> CompoundOperationWrapper<DAppBrowserTab>

    func updateRenderForTab(
        with id: UUID,
        render: Data?
    ) -> CompoundOperationWrapper<DAppBrowserTab>

    func removeTab(with id: UUID)

    func removeAll()

    func addObserver(_ observer: DAppBrowserTabsObserver)
}

enum DAppBrowserTabManagerError: Error {
    case renderCacheFailed
    case tabNotPersisted
}

final class DAppBrowserTabManager {
    private let cacheBasePath: String
    private let fileRepository: FileRepositoryProtocol
    private let repository: CoreDataRepository<DAppBrowserTab.PersistenceModel, CDDAppBrowserTab>
    private let operationQueue: OperationQueue
    private let observerQueue: DispatchQueue

    private let logger: LoggerProtocol

    private var dAppTransportStates: [UUID: [DAppTransportState]] = [:]
    private var tabs: [UUID: DAppBrowserTab] = [:]

    private var observers: [WeakWrapper] = []

    init(
        cacheBasePath: String,
        fileRepository: FileRepositoryProtocol,
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
        guard let localPath = createLocalPath(tab.uuid.uuidString) else {
            return .createWithError(DAppBrowserTabManagerError.renderCacheFailed)
        }

        let persistenceModel = tab.persistenceModel

        let saveTabOperation = repository.saveOperation(
            { [persistenceModel] },
            { [] }
        )

        let saveRenderOperation: BaseOperation<Void> = if let renderData = tab.stateRender {
            fileRepository.writeOperation(
                dataClosure: { renderData },
                at: localPath
            )
        } else {
            fileRepository.removeOperation(at: localPath)
        }

        let resultOperation = ClosureOperation { [weak self] in
            _ = try saveTabOperation.extractNoCancellableResultData()
            _ = try saveRenderOperation.extractNoCancellableResultData()

            self?.tabs[tab.uuid] = tab
            self?.dAppTransportStates[tab.uuid] = tab.transportStates

            self?.notifyObservers()

            return tab
        }
        resultOperation.addDependency(saveTabOperation)
        resultOperation.addDependency(saveRenderOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: [saveTabOperation, saveRenderOperation]
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

            guard let localPath = createLocalPath(tabId.uuidString) else {
                return .createWithError(DAppBrowserTabManagerError.renderCacheFailed)
            }

            let fetchRenderOperation = fileRepository.readOperation(at: localPath)

            let resultOperation = ClosureOperation<DAppBrowserTab?> { [weak self] in
                guard let fetchResult = try fetchTabOperation.extractNoCancellableResultData() else {
                    return nil
                }

                let iconURL: URL? = if let urlString = fetchResult.icon {
                    URL(string: urlString)
                } else {
                    nil
                }

                let render = try fetchRenderOperation.extractNoCancellableResultData()

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

            return CompoundOperationWrapper(
                targetOperation: resultOperation,
                dependencies: [fetchTabOperation]
            )
        }
    }

    func createFetchAllRendersWrapper(
        using fetchAllOperation: BaseOperation<[DAppBrowserTab.PersistenceModel]>
    ) -> CompoundOperationWrapper<[UUID: Data]> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] in
            guard let self else {
                return .createWithError(BaseOperationError.parentOperationCancelled)
            }

            let tabs = try fetchAllOperation.extractNoCancellableResultData()

            let fetchRenderOperations: [UUID: BaseOperation<Data?>] = tabs.reduce(into: [:]) { acc, tab in
                guard let localPath = self.createLocalPath(tab.identifier) else {
                    return
                }

                acc[tab.uuid] = self.fileRepository.readOperation(at: localPath)
            }

            return createRendersMappingWrapper(using: fetchRenderOperations)
        }
    }

    func createRendersMappingWrapper(
        using fetchOperations: [UUID: BaseOperation<Data?>]
    ) -> CompoundOperationWrapper<[UUID: Data]> {
        let operations = Array(fetchOperations.values)
        let closureOperation = ClosureOperation<[UUID: Data]> {
            fetchOperations.reduce(into: [:]) { acc, operation in
                acc[operation.key] = try? operation.value.extractNoCancellableResultData()
            }
        }

        return CompoundOperationWrapper(
            targetOperation: closureOperation,
            dependencies: Array(fetchOperations.values)
        )
    }

    func createLocalPath(_ fileName: String) -> String? {
        let localFilePath = (cacheBasePath as NSString).appendingPathComponent(fileName)

        let filePathComponentsCount = (localFilePath as NSString).pathComponents.count
        let basePathComponentsCount = (cacheBasePath as NSString).pathComponents.count

        guard filePathComponentsCount > basePathComponentsCount else {
            return nil
        }

        return localFilePath
    }
}

// MARK: DAppBrowserTabManagerProtocol

extension DAppBrowserTabManager: DAppBrowserTabManagerProtocol {
    func retrieveTab(with id: UUID) -> CompoundOperationWrapper<DAppBrowserTab?> {
        retrieveWrapper(for: id)
    }

    func getAllTabs() -> CompoundOperationWrapper<[DAppBrowserTab]> {
        let currentTabs = tabs
            .values
            .sorted { $0.lastModified < $1.lastModified }

        guard currentTabs.isEmpty else {
            return .createWithResult(currentTabs)
        }

        let fetchTabsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        let fetchRendersWrapper = createFetchAllRendersWrapper(using: fetchTabsOperation)

        let resultOperaton = ClosureOperation { [weak self] in
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
                    transportStates: self?.dAppTransportStates[persistenceModel.uuid],
                    stateRender: renders[persistenceModel.uuid],
                    desktopOnly: persistenceModel.desktopOnly,
                    icon: iconURL
                )
            }

            tabs.forEach { self?.tabs[$0.uuid] = $0 }

            return tabs
        }
        resultOperaton.addDependency(fetchTabsOperation)

        let wrapper = CompoundOperationWrapper(
            targetOperation: resultOperaton,
            dependencies: fetchRendersWrapper.allOperations
        )

        wrapper.addDependency(wrapper: fetchRendersWrapper)

        return wrapper
    }

    func removeTab(with id: UUID) {
        guard let model = tabs[id]?.persistenceModel else {
            return
        }

        tabs[id] = nil

        let deleteOperation = repository.saveOperation(
            { [] },
            { [model.identifier] }
        )

        execute(
            operation: deleteOperation,
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
        let deleteOperation = repository.deleteAllOperation()

        execute(
            operation: deleteOperation,
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

        return DAppBrowserTabManager(
            cacheBasePath: ApplicationConfig.shared.fileCachePath,
            fileRepository: FileRepository(),
            repository: coreDataRepository,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
    }()
}
