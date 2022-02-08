import UIKit
import RobinHood

final class DAppBrowserInteractor {
    struct QueueMessage {
        let transportName: String
        let underliningMessage: Any
    }

    weak var presenter: DAppBrowserInteractorOutputProtocol!

    private(set) var userQuery: DAppSearchResult
    let dataSource: DAppBrowserStateDataSource
    let logger: LoggerProtocol?
    let transports: [DAppBrowserTransportProtocol]

    private(set) var messageQueue: [QueueMessage] = []

    init(
        transports: [DAppBrowserTransportProtocol],
        userQuery: DAppSearchResult,
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        dAppSettingsRepository: AnyDataProviderRepository<DAppSettings>,
        operationQueue: OperationQueue,
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

    func provideModel() {
        guard let url = resolveUrl() else {
            presenter.didReceive(error: DAppBrowserInteractorError.invalidUrl)
            return
        }

        let wrappers: [CompoundOperationWrapper<DAppTransportModel>] = transports.map { transport in
            let bridgeOperation = transport.createBridgeScriptOperation()
            let subscriptionScript = transport.createSubscriptionScript()
            let transportName = transport.name

            let mapOperation = ClosureOperation<DAppTransportModel> {
                let bridgeScript = try bridgeOperation.extractNoCancellableResultData()

                return DAppTransportModel(
                    name: transportName,
                    scripts: [bridgeScript, subscriptionScript]
                )
            }

            mapOperation.addDependency(bridgeOperation)

            return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [bridgeOperation])
        }

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

    private func processMessageIfNeeded() {
        guard transports.allSatisfy({ $0.isIdle() }), let queueMessage = messageQueue.first else {
            return
        }

        messageQueue.removeFirst()

        let transport = transports.first { $0.name == queueMessage.transportName }

        transport?.process(message: queueMessage.underliningMessage)
    }
}

extension DAppBrowserInteractor: DAppBrowserInteractorInputProtocol {
    func setup() {
        subscribeChainRegistry()
    }

    func process(message: Any, forTransport name: String) {
        logger?.debug("Did receive message: \(message)")

        let queueMessage = QueueMessage(transportName: name, underliningMessage: message)
        messageQueue.append(queueMessage)

        processMessageIfNeeded()
    }

    func processConfirmation(response: DAppOperationResponse, forTransport name: String) {
        transports.first(where: { $0.name == name })?.processConfirmation(response: response)
    }

    func process(newQuery: DAppSearchResult) {
        userQuery = newQuery

        transports.forEach { $0.stop() }
        completeSetupIfNeeded()
    }

    func processAuth(response: DAppAuthResponse, forTransport name: String) {
        transports.first(where: { $0.name == name })?.processAuth(response: response)
    }

    func reload() {
        transports.forEach { $0.stop() }
        completeSetupIfNeeded()
    }
}

extension DAppBrowserInteractor: DAppBrowserTransportDelegate {
    func dAppTransport(
        _ transport: DAppBrowserTransportProtocol,
        didReceiveResponse response: PolkadotExtensionResponse
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
}
