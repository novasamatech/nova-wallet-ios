import UIKit
import Operation_iOS
import Foundation_iOS

final class DAppBrowserInteractor {
    struct QueueMessage {
        let host: String
        let transportName: String
        let underliningMessage: Any
    }

    weak var presenter: DAppBrowserInteractorOutputProtocol?

    private(set) var currentTab: DAppBrowserTab

    var dataSource: DAppBrowserStateDataSource
    let logger: LoggerProtocol?
    let transports: [DAppBrowserTransportProtocol]
    let sequentialPhishingVerifier: PhishingSiteVerifing
    let dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactoryProtocol
    let dAppsFavoriteRepository: AnyDataProviderRepository<DAppFavorite>
    let dAppGlobalSettingsRepository: AnyDataProviderRepository<DAppGlobalSettings>
    let securedLayer: SecurityLayerServiceProtocol
    let tabManager: DAppBrowserTabManagerProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let attestHandler: DAppAttestHandlerProtocol

    let operationQueue: OperationQueue

    private var favoriteDAppsProvider: StreamableProvider<DAppFavorite>?
    private var tabs: [DAppBrowserTab] = []

    private(set) var messageQueue: [QueueMessage] = []

    init(
        transports: [DAppBrowserTransportProtocol],
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
        applicationHandler: ApplicationHandlerProtocol,
        attestHandler: DAppAttestHandlerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.transports = transports
        currentTab = selectedTab
        self.operationQueue = operationQueue
        self.logger = logger
        self.sequentialPhishingVerifier = sequentialPhishingVerifier
        self.dAppsFavoriteRepository = dAppsFavoriteRepository
        self.dAppsLocalSubscriptionFactory = dAppsLocalSubscriptionFactory
        self.dAppGlobalSettingsRepository = dAppGlobalSettingsRepository
        self.tabManager = tabManager
        self.applicationHandler = applicationHandler
        self.attestHandler = attestHandler
        self.securedLayer = securedLayer

        if let existingDataSource = currentTab.transportStates?.first?.dataSource {
            dataSource = existingDataSource
        } else {
            dataSource = DAppBrowserStateDataSource(
                wallet: wallet,
                chainRegistry: chainRegistry,
                dAppSettingsRepository: dAppSettingsRepository,
                operationQueue: operationQueue,
                tab: selectedTab
            )
        }
    }
}

// MARK: Private

private extension DAppBrowserInteractor {
    func setupState() {
        if let existingTabStates = currentTab.transportStates {
            existingTabStates.forEach { state in
                transports.forEach { transport in
                    transport.delegate = self
                    transport.restoreState(from: state)
                }
            }
        } else {
            transports.forEach { transport in
                transport.delegate = self
                transport.start(with: dataSource)
            }
        }
    }

    func subscribeChainRegistry() {
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

            self?.provideModel()
        }
    }

    func completeSetupIfNeeded() {
        if !dataSource.chainStore.isEmpty {
            transports.forEach { transport in
                transport.delegate = self
                transport.start(with: dataSource)
            }

            provideModel()
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

        let desktopOnly = currentTab.desktopOnly ?? false

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

    func processMessageIfNeeded() {
        guard transports.allSatisfy({ $0.isIdle() }), let queueMessage = messageQueue.first else {
            return
        }

        messageQueue.removeFirst()

        let transport = transports.first { $0.name == queueMessage.transportName }

        transport?.process(message: queueMessage.underliningMessage, host: queueMessage.host)
    }

    func bringPhishingDetectedStateAndNotify(for host: String) {
        let allPhishing = transports
            .map { $0.bringPhishingDetectedStateIfNeeded() }
            .allSatisfy { !$0 }

        if !allPhishing {
            presenter?.didDetectPhishing(host: host)
        }
    }

    func verifyPhishing(for host: String, completion: ((Bool) -> Void)?) {
        sequentialPhishingVerifier.verify(host: host) { [weak self] result in
            guard let self else { return }

            switch result {
            case let .success(isNotPhishing):
                if !isNotPhishing {
                    bringPhishingDetectedStateAndNotify(for: host)
                }

                completion?(isNotPhishing)
            case let .failure(error):
                presenter?.didReceive(error: error)
            }
        }
    }

    func provideTabs() {
        let allTabsWrapper = tabManager.getAllTabs()

        execute(
            wrapper: allTabsWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self else { return }

            switch result {
            case let .success(tabs):
                self.tabs = tabs

                // In case we haven't loaded current tab yet so it is not persisted
                let outputTabs: [DAppBrowserTab] = if tabs.contains(
                    where: { $0.uuid == self.currentTab.uuid }
                ) {
                    tabs
                } else {
                    tabs + [currentTab]
                }

                presenter?.didReceiveTabs(outputTabs)
            case let .failure(error):
                presenter?.didReceive(error: error)
            }
        }
    }

    func proceedWithTabUpdate(with searchResult: DAppSearchResult) {
        guard let updatedTab = currentTab.updating(with: searchResult) else {
            return
        }

        let updateWrapper = tabManager.updateTab(updatedTab)

        dataSource.replace(tab: updatedTab)

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

    func proceedWithNewTab(opening dApp: DApp) {
        let newTab = DAppBrowserTab(
            from: dApp,
            metaId: dataSource.wallet.metaId
        )

        let states = transports.compactMap { $0.makeOpaqueState() }

        storeTab(currentTab.updating(transportStates: states))

        dataSource.replace(tab: newTab)

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

    func storeTab(_ tab: DAppBrowserTab) {
        let tabSaveWrapper = tabManager.updateTab(tab)

        execute(
            wrapper: tabSaveWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.provideTabs()
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }
    }

    func createTransportSaveWrapper() -> CompoundOperationWrapper<DAppBrowserTab> {
        let transportStates = transports.compactMap { $0.makeOpaqueState() }

        return tabManager.updateTab(currentTab.updating(transportStates: transportStates))
    }
}

// MARK: DAppBrowserInteractorInputProtocol

extension DAppBrowserInteractor: DAppBrowserInteractorInputProtocol {
    func setup() {
        storeTab(currentTab)

        applicationHandler.delegate = self
        attestHandler.delegate = self

        setupState()
        provideTabs()

        subscribeChainRegistry()

        favoriteDAppsProvider = subscribeToFavoriteDApps(nil)
    }

    func process(host: String) {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.verifyPhishing(for: host, completion: nil)
        }
    }

    func processConfirmation(
        response: DAppOperationResponse,
        forTransport name: String
    ) {
        transports.first(where: { $0.name == name })?.processConfirmation(response: response)
    }

    func process(stateRender: DAppBrowserTabRenderProtocol) {
        let transportSaveWrapper = createTransportSaveWrapper()

        let renderUpdateWrapper = tabManager.updateRenderForTab(
            with: currentTab.uuid,
            render: stateRender
        )

        renderUpdateWrapper.addDependency(wrapper: transportSaveWrapper)

        let totalWrapper = renderUpdateWrapper.insertingHead(operations: transportSaveWrapper.allOperations)

        operationQueue.addOperations(
            totalWrapper.allOperations,
            waitUntilFinished: false
        )
    }

    func process(newQuery: DAppSearchResult) {
        sequentialPhishingVerifier.cancelAll()

        if case let .dApp(dApp) = newQuery {
            proceedWithNewTab(opening: dApp)
        } else {
            proceedWithTabUpdate(with: newQuery)
        }
    }

    func process(
        message: Any,
        host: String,
        transport name: String
    ) {
        // MARK: Integrity check

        guard !attestHandler.canHandle(transportName: name) else {
            attestHandler.handle(message: message)
            return
        }

        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.logger?.debug("Did receive \(name) message from \(host): \(message)")

            self?.verifyPhishing(for: host) { isNotPhishing in
                guard isNotPhishing else { return }

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

    func createTransportWrappers() -> [CompoundOperationWrapper<DAppTransportModel>] {
        var wrappers = transports.map { transport in
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
                    handlerNames: [transportName],
                    scripts: [bridgeScript, subscriptionScript]
                )
            }

            mapOperation.addDependency(bridgeOperation)

            return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [bridgeOperation])
        }

        // MARK: Integrity check

        let attestModel = attestHandler.createTransportModel()
        wrappers.append(.createWithResult(attestModel))

        return wrappers
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

    func saveTabIfNeeded() {
        guard !tabs.contains(currentTab) else {
            return
        }

        storeTab(currentTab)
    }

    func saveLastTabState(render: DAppBrowserTabRenderProtocol) {
        let transportSaveWrapper = createTransportSaveWrapper()

        let renderUpdateWrapper = tabManager.updateRenderForTab(
            with: currentTab.uuid,
            render: render
        )

        renderUpdateWrapper.addDependency(wrapper: transportSaveWrapper)

        let resultWrapper = renderUpdateWrapper.insertingHead(operations: transportSaveWrapper.allOperations)

        execute(
            wrapper: resultWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] _ in
            self?.presenter?.didSaveLastTabState()
        }
    }

    func close() {
        tabManager.removeTab(with: currentTab.uuid)
    }
}

// MARK: DAppBrowserTransportDelegate

extension DAppBrowserInteractor: DAppBrowserTransportDelegate {
    func dAppTransport(
        _: DAppBrowserTransportProtocol,
        didReceiveResponse response: DAppScriptResponse
    ) {
        presenter?.didReceive(response: response)
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

// MARK: DAppLocalStorageSubscriber

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

// MARK: ApplicationHandlerDelegate

extension DAppBrowserInteractor: ApplicationHandlerDelegate {
    func didReceiveWillResignActive(notification _: Notification) {
        presenter?.didReceiveRenderRequest()

        let transportSaveWrapper = createTransportSaveWrapper()

        operationQueue.addOperations(
            transportSaveWrapper.allOperations,
            waitUntilFinished: false
        )
    }
}

// MARK: - DAppAttestHandlerDelegate

extension DAppBrowserInteractor: DAppAttestHandlerDelegate {
    func handleResponse(_ response: DAppScriptResponse) {
        presenter?.didReceive(response: response)
    }
}
