import UIKit
import Operation_iOS

final class DAppBrowserInteractor {
    struct QueueMessage {
        let host: String
        let transportName: String
        let underliningMessage: Any
    }

    weak var presenter: DAppBrowserInteractorOutputProtocol?

    private(set) var userQuery: DAppSearchResult
    private(set) var currentTab: DAppBrowserTab

    let dataSource: DAppBrowserStateDataSource
    let logger: LoggerProtocol?
    let transports: [DAppBrowserTransportProtocol]
    let sequentialPhishingVerifier: PhishingSiteVerifing
    let dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactoryProtocol
    let dAppsFavoriteRepository: AnyDataProviderRepository<DAppFavorite>
    let dAppGlobalSettingsRepository: AnyDataProviderRepository<DAppGlobalSettings>
    let securedLayer: SecurityLayerServiceProtocol
    let tabManager: DAppBrowserTabManagerProtocol

    let operationQueue: OperationQueue

    private var favoriteDAppsProvider: StreamableProvider<DAppFavorite>?

    private(set) var messageQueue: [QueueMessage] = []

    init(
        transports: [DAppBrowserTransportProtocol],
        userQuery: DAppSearchResult,
        selectedTab: DAppBrowserTab,
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        securedLayer: SecurityLayerServiceProtocol,
        dAppSettingsRepository: AnyDataProviderRepository<DAppSettings>,
        dAppGlobalSettingsRepository: AnyDataProviderRepository<DAppGlobalSettings>,
        dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactoryProtocol,
        dAppsFavoriteRepository: AnyDataProviderRepository<DAppFavorite>,
        operationQueue: OperationQueue,
        sequentialPhishingVerifier: PhishingSiteVerifing,
        tabManager: DAppBrowserTabManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.transports = transports
        self.userQuery = userQuery
        currentTab = selectedTab
        self.operationQueue = operationQueue
        dataSource = DAppBrowserStateDataSource(
            wallet: wallet,
            chainRegistry: chainRegistry,
            dAppSettingsRepository: dAppSettingsRepository,
            operationQueue: operationQueue,
            dApp: userQuery.dApp
        )
        self.logger = logger
        self.sequentialPhishingVerifier = sequentialPhishingVerifier
        self.dAppsFavoriteRepository = dAppsFavoriteRepository
        self.dAppsLocalSubscriptionFactory = dAppsLocalSubscriptionFactory
        self.dAppGlobalSettingsRepository = dAppGlobalSettingsRepository
        self.tabManager = tabManager
        self.securedLayer = securedLayer
    }

    private func subscribeChainRegistry() {
        dataSource.chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main,
            filterStrategy: .enabledChains
        ) { [weak self] changes in
            for change in changes {
                switch change {
                case let .insert(newItem):
                    self?.dataSource.set(chain: newItem, for: newItem.identifier)
                case let .update(newItem):
                    self?.dataSource.set(chain: newItem, for: newItem.identifier)
                case let .delete(deletedIdentifier):
                    self?.dataSource.set(chain: nil, for: deletedIdentifier)
                }
            }

            self?.completeSetupIfNeeded()
        }
    }

    private func completeSetupIfNeeded() {
        if !dataSource.chainStore.isEmpty {
            transports.forEach { transport in
                transport.delegate = self
                transport.start(with: dataSource)
            }

            provideModel()
        }
    }

    func createTransportWrappers() -> [CompoundOperationWrapper<DAppTransportModel>] {
        transports.map { transport in
            let bridgeOperation = transport.createBridgeScriptOperation()
            let maybeSubscriptionScript = transport.createSubscriptionScript(for: dataSource)
            let transportName = transport.name

            let mapOperation = ClosureOperation<DAppTransportModel> {
                guard let subscriptionScript = maybeSubscriptionScript else {
                    throw DAppBrowserStateError.unexpected(
                        reason: "Selected wallet doesn't have an address for this network"
                    )
                }

                let bridgeScript = try bridgeOperation.extractNoCancellableResultData()

                return DAppTransportModel(
                    name: transportName,
                    scripts: [bridgeScript, subscriptionScript]
                )
            }

            mapOperation.addDependency(bridgeOperation)

            return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [bridgeOperation])
        }
    }

    func createGlobalSettingsOperation(for host: String?) -> BaseOperation<DAppGlobalSettings?> {
        guard let host = host else {
            return BaseOperation.createWithResult(nil)
        }

        return dAppGlobalSettingsRepository.fetchOperation(by: host, options: RepositoryFetchOptions())
    }

    func provideModel() {
        let wrappers = createTransportWrappers()

        let globalSettingsOperation = createGlobalSettingsOperation(for: currentTab.url.host)

        let desktopOnly = userQuery.dApp?.desktopOnly ?? false

        let mapOperation = ClosureOperation<DAppBrowserModel> { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let transportModels = try wrappers.map { wrapper in
                try wrapper.targetOperation.extractNoCancellableResultData()
            }

            let dAppSettings = try globalSettingsOperation.extractNoCancellableResultData()

            let isDesktop = dAppSettings?.desktopMode ?? desktopOnly

            return DAppBrowserModel(
                selectedTab: currentTab,
                isDesktop: isDesktop,
                transports: transportModels
            )
        }

        wrappers.forEach { mapOperation.addDependency($0.targetOperation) }
        mapOperation.addDependency(globalSettingsOperation)

        mapOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let model = try mapOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveDApp(model: model)
                } catch {
                    self?.presenter?.didReceive(error: error)
                }
            }
        }

        let dependencies = wrappers.flatMap(\.allOperations) + [globalSettingsOperation]

        dataSource.operationQueue.addOperations(dependencies + [mapOperation], waitUntilFinished: false)
    }

    func provideTransportUpdate(with postExecutionScript: DAppScriptResponse) {
        let wrappers = createTransportWrappers()

        let mapOperation = ClosureOperation<[DAppTransportModel]> {
            try wrappers.map { wrapper in
                try wrapper.targetOperation.extractNoCancellableResultData()
            }
        }

        wrappers.forEach { mapOperation.addDependency($0.targetOperation) }

        mapOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let models = try mapOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveReplacement(
                        transports: models,
                        postExecution: postExecutionScript
                    )
                } catch {
                    self?.presenter?.didReceive(error: error)
                }
            }
        }

        let dependencies = wrappers.flatMap(\.allOperations)

        dataSource.operationQueue.addOperations(dependencies + [mapOperation], waitUntilFinished: false)
    }

    private func processMessageIfNeeded() {
        guard transports.allSatisfy({ $0.isIdle() }), let queueMessage = messageQueue.first else {
            return
        }

        messageQueue.removeFirst()

        let transport = transports.first { $0.name == queueMessage.transportName }

        transport?.process(message: queueMessage.underliningMessage, host: queueMessage.host)
    }

    private func bringPhishingDetectedStateAndNotify(for host: String) {
        let allPhishing = transports
            .map { $0.bringPhishingDetectedStateIfNeeded() }
            .allSatisfy { !$0 }

        if !allPhishing {
            presenter?.didDetectPhishing(host: host)
        }
    }

    private func verifyPhishing(for host: String, completion: ((Bool) -> Void)?) {
        sequentialPhishingVerifier.verify(host: host) { [weak self] result in
            switch result {
            case let .success(isNotPhishing):
                if !isNotPhishing {
                    self?.bringPhishingDetectedStateAndNotify(for: host)
                }

                completion?(isNotPhishing)
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }
    }

    private func provideTabs() {
        let allTabsWrapper = tabManager.getAllTabs()

        execute(
            wrapper: allTabsWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(tabs):
                self?.presenter?.didReceiveTabs(tabs)
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }
    }

    private func proceedWithTabUpdate(with query: String) {
        let url = DAppBrowserTab.resolveUrl(for: query)
        let updateWrapper = tabManager.updateTab(currentTab.updating(url: url))

        execute(
            wrapper: updateWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(updatedTab):
                self?.currentTab = updatedTab
                self?.transports.forEach { $0.stop() }
                self?.completeSetupIfNeeded()
                self?.provideTabs()
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }
    }

    private func proceedWithNewTab(opening dApp: DApp) {
        guard let newTab = DAppBrowserTab(from: .dApp(model: dApp)) else {
            return
        }

        let states = transports.compactMap { $0.makeOpaqueState() }

        tabManager.updateTab(currentTab.updating(state: states))

        dataSource.replace(dApp: dApp)

        let newTabSaveWrapper = tabManager.updateTab(newTab)

        execute(
            wrapper: newTabSaveWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(model):
                self?.currentTab = model
                self?.transports.forEach { $0.stop() }
                self?.completeSetupIfNeeded()
                self?.provideTabs()
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }
    }
}

extension DAppBrowserInteractor: DAppBrowserInteractorInputProtocol {
    func setup() {
        subscribeChainRegistry()

        favoriteDAppsProvider = subscribeToFavoriteDApps(nil)

        let tabSaveWrapper = tabManager.updateTab(currentTab)

        execute(
            wrapper: tabSaveWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(tab):
                self?.provideTabs()
                self?.completeSetupIfNeeded()
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }
    }

    func process(host: String) {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.verifyPhishing(for: host, completion: nil)
        }
    }

    func process(message: Any, host: String, transport name: String) {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.logger?.debug("Did receive \(name) message from \(host): \(message)")

            self?.verifyPhishing(for: host) { [weak self] isNotPhishing in
                if isNotPhishing {
                    let queueMessage = QueueMessage(
                        host: host,
                        transportName: name,
                        underliningMessage: message
                    )
                    self?.messageQueue.append(queueMessage)

                    self?.processMessageIfNeeded()
                }
            }
        }
    }

    func processConfirmation(response: DAppOperationResponse, forTransport name: String) {
        transports.first(where: { $0.name == name })?.processConfirmation(response: response)
    }

    func process(newQuery: DAppSearchResult) {
        sequentialPhishingVerifier.cancelAll()

        userQuery = newQuery

        switch newQuery {
        case let .query(query):
            proceedWithTabUpdate(with: query)
        case let .dApp(dApp):
            proceedWithNewTab(opening: dApp)
        }
    }

    func processAuth(response: DAppAuthResponse, forTransport name: String) {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.transports.first(where: { $0.name == name })?.processAuth(response: response)
        }
    }

    func removeFromFavorites(record: DAppFavorite) {
        let operation = dAppsFavoriteRepository.saveOperation({ [] }, { [record.identifier] })
        dataSource.operationQueue.addOperation(operation)
    }

    func reload() {
        transports.forEach { $0.stop() }
        completeSetupIfNeeded()
    }

    func save(settings: DAppGlobalSettings) {
        let saveOperation = dAppGlobalSettingsRepository.saveOperation({
            [settings]
        }, { [] })

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                if case .success = saveOperation.result {
                    self?.presenter?.didChangeGlobal(settings: settings)
                }
            }
        }

        dataSource.operationQueue.addOperation(saveOperation)
    }
}

extension DAppBrowserInteractor: DAppBrowserTransportDelegate {
    func dAppTransport(
        _ transport: DAppBrowserTransportProtocol,
        didReceiveResponse response: DAppScriptResponse
    ) {
        presenter?.didReceive(response: response, forTransport: transport.name)
    }

    func dAppTransport(_: DAppBrowserTransportProtocol, didReceiveAuth request: DAppAuthRequest) {
        presenter?.didReceiveAuth(request: request)
    }

    func dAppTransport(
        _: DAppBrowserTransportProtocol,
        didReceiveConfirmation request: DAppOperationRequest,
        of type: DAppSigningType
    ) {
        presenter?.didReceiveConfirmation(request: request, type: type)
    }

    func dAppTransport(_: DAppBrowserTransportProtocol, didReceive error: Error) {
        presenter?.didReceive(error: error)
    }

    func dAppTransportAsksPopMessage(_: DAppBrowserTransportProtocol) {
        processMessageIfNeeded()
    }

    func dAppAskReload(
        _: DAppBrowserTransportProtocol,
        postExecutionScript: DAppScriptResponse
    ) {
        provideTransportUpdate(with: postExecutionScript)
    }
}

extension DAppBrowserInteractor: DAppLocalStorageSubscriber, DAppLocalSubscriptionHandler {
    func handleFavoriteDApps(result: Result<[DataProviderChange<DAppFavorite>], Error>) {
        switch result {
        case let .success(changes):
            presenter?.didReceiveFavorite(changes: changes)
        case let .failure(error):
            logger?.error("Unexpected database error: \(error)")
        }
    }
}
