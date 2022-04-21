import UIKit
import RobinHood

final class DAppBrowserInteractor {
    struct QueueMessage {
        let host: String
        let transportName: String
        let underliningMessage: Any
    }

    weak var presenter: DAppBrowserInteractorOutputProtocol!

    private(set) var userQuery: DAppSearchResult
    let dataSource: DAppBrowserStateDataSource
    let logger: LoggerProtocol?
    let transports: [DAppBrowserTransportProtocol]
    let sequentialPhishingVerifier: PhishingSiteVerifing
    let dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactoryProtocol
    let dAppsFavoriteRepository: AnyDataProviderRepository<DAppFavorite>

    private var favoriteDAppsProvider: StreamableProvider<DAppFavorite>?

    private(set) var messageQueue: [QueueMessage] = []

    init(
        transports: [DAppBrowserTransportProtocol],
        userQuery: DAppSearchResult,
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        dAppSettingsRepository: AnyDataProviderRepository<DAppSettings>,
        dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactoryProtocol,
        dAppsFavoriteRepository: AnyDataProviderRepository<DAppFavorite>,
        operationQueue: OperationQueue,
        sequentialPhishingVerifier: PhishingSiteVerifing,
        logger: LoggerProtocol? = nil
    ) {
        self.transports = transports
        self.userQuery = userQuery
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
    }

    private func subscribeChainRegistry() {
        dataSource.chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
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

    func resolveUrl() -> URL? {
        switch userQuery {
        case let .dApp(model):
            return model.url
        case let .query(string):
            var urlComponents = URLComponents(string: string)

            if urlComponents?.scheme == nil {
                urlComponents?.scheme = "https"
            }

            if NSPredicate.urlPredicate.evaluate(with: string), let inputUrl = urlComponents?.url {
                return inputUrl
            } else {
                let querySet = CharacterSet.urlQueryAllowed
                guard let searchQuery = string.addingPercentEncoding(withAllowedCharacters: querySet) else {
                    return nil
                }

                return URL(string: "https://duckduckgo.com/?q=\(searchQuery)")
            }
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

    func provideModel() {
        guard let url = resolveUrl() else {
            presenter.didReceive(error: DAppBrowserInteractorError.invalidUrl)
            return
        }

        let wrappers = createTransportWrappers()

        let mapOperation = ClosureOperation<DAppBrowserModel> {
            let tranportModels = try wrappers.map { wrapper in
                try wrapper.targetOperation.extractNoCancellableResultData()
            }

            return DAppBrowserModel(url: url, transports: tranportModels)
        }

        wrappers.forEach { mapOperation.addDependency($0.targetOperation) }

        mapOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let model = try mapOperation.extractNoCancellableResultData()
                    self?.presenter.didReceiveDApp(model: model)
                } catch {
                    self?.presenter.didReceive(error: error)
                }
            }
        }

        let dependencies = wrappers.flatMap(\.allOperations)

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
                    self?.presenter.didReceiveReplacement(
                        transports: models,
                        postExecution: postExecutionScript
                    )
                } catch {
                    self?.presenter.didReceive(error: error)
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
            presenter.didDetectPhishing(host: host)
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
                self?.presenter.didReceive(error: error)
            }
        }
    }
}

extension DAppBrowserInteractor: DAppBrowserInteractorInputProtocol {
    func setup() {
        subscribeChainRegistry()

        favoriteDAppsProvider = subscribeToFavoriteDApps(nil)
    }

    func process(host: String) {
        verifyPhishing(for: host, completion: nil)
    }

    func process(message: Any, host: String, transport name: String) {
        logger?.debug("Did receive \(name) message from \(host): \(message)")

        verifyPhishing(for: host) { [weak self] isNotPhishing in
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

    func processConfirmation(response: DAppOperationResponse, forTransport name: String) {
        transports.first(where: { $0.name == name })?.processConfirmation(response: response)
    }

    func process(newQuery: DAppSearchResult) {
        sequentialPhishingVerifier.cancelAll()

        userQuery = newQuery

        transports.forEach { $0.stop() }
        completeSetupIfNeeded()
    }

    func processAuth(response: DAppAuthResponse, forTransport name: String) {
        transports.first(where: { $0.name == name })?.processAuth(response: response)
    }

    func removeFromFavorites(record: DAppFavorite) {
        let operation = dAppsFavoriteRepository.saveOperation({ [] }, { [record.identifier] })
        dataSource.operationQueue.addOperation(operation)
    }

    func reload() {
        transports.forEach { $0.stop() }
        completeSetupIfNeeded()
    }
}

extension DAppBrowserInteractor: DAppBrowserTransportDelegate {
    func dAppTransport(
        _ transport: DAppBrowserTransportProtocol,
        didReceiveResponse response: DAppScriptResponse
    ) {
        presenter.didReceive(response: response, forTransport: transport.name)
    }

    func dAppTransport(_: DAppBrowserTransportProtocol, didReceiveAuth request: DAppAuthRequest) {
        presenter.didReceiveAuth(request: request)
    }

    func dAppTransport(
        _: DAppBrowserTransportProtocol,
        didReceiveConfirmation request: DAppOperationRequest,
        of type: DAppSigningType
    ) {
        presenter.didReceiveConfirmation(request: request, type: type)
    }

    func dAppTransport(_: DAppBrowserTransportProtocol, didReceive error: Error) {
        presenter.didReceive(error: error)
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
            presenter.didReceiveFavorite(changes: changes)
        case let .failure(error):
            logger?.error("Unexpected database error: \(error)")
        }
    }
}
