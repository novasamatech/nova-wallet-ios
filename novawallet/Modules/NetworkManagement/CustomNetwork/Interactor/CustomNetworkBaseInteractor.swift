import Foundation
import SubstrateSdk
import Operation_iOS

class CustomNetworkBaseInteractor: NetworkNodeCreatorTrait {
    weak var presenter: CustomNetworkBaseInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol
    let customNetworkSetupFactory: CustomNetworkSetupFactoryProtocol
    let connectionFactory: ConnectionFactoryProtocol
    let repository: AnyDataProviderRepository<ChainModel>
    let priceIdParser: PriceUrlParserProtocol
    let operationQueue: OperationQueue

    let setupFinishStrategyFactory: CustomNetworkSetupFinishStrategyFactory

    var currentConnectingNode: ChainNodeModel?
    var currentConnection: ChainConnection?

    var setupNetworkWrapper: CompoundOperationWrapper<ChainModel>?
    var setupFinishStrategy: CustomNetworkSetupFinishStrategy?

    private var partialChain: PartialCustomChainModel?

    private var setupNetworkCancellable = CancellableCallStore()

    init(
        chainRegistry: ChainRegistryProtocol,
        customNetworkSetupFactory: CustomNetworkSetupFactoryProtocol,
        connectionFactory: ConnectionFactoryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        priceIdParser: PriceUrlParserProtocol,
        setupFinishStrategyFactory: CustomNetworkSetupFinishStrategyFactory,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.customNetworkSetupFactory = customNetworkSetupFactory
        self.connectionFactory = connectionFactory
        self.repository = repository
        self.priceIdParser = priceIdParser
        self.setupFinishStrategyFactory = setupFinishStrategyFactory
        self.operationQueue = operationQueue
    }

    func setup() {
        completeSetup()
    }

    func modify(with request: CustomNetwork.ModifyRequest) {
        setupFinishStrategy = setupFinishStrategyFactory.createModifyStrategy(
            networkToModify: request.existingNetwork
        )

        let mainAsset = request.existingNetwork.assets.first(where: { $0.assetId == 0 })

        let evmChainId: UInt64? = if let chainId = request.chainId, let intChainId = Int(chainId) {
            UInt64(intChainId)
        } else {
            nil
        }

        do {
            let priceId = try extractPriceId(from: request.coingeckoURL) ?? mainAsset?.priceId

            let partialChain = PartialCustomChainModel(
                chainId: request.existingNetwork.chainId,
                url: request.url,
                name: request.name,
                iconUrl: request.existingNetwork.icon,
                assets: request.existingNetwork.assets,
                nodes: request.existingNetwork.nodes,
                currencySymbol: mainAsset?.symbol ?? request.currencySymbol,
                options: request.existingNetwork.options,
                nodeSwitchStrategy: request.existingNetwork.nodeSwitchStrategy,
                addressPrefix: evmChainId ?? request.existingNetwork.addressPrefix,
                connectionMode: .autoBalanced,
                blockExplorer: createExplorer(
                    from: request.blockExplorerURL,
                    chainName: request.name
                ) ?? request.existingNetwork.explorers?.first,
                mainAssetPriceId: priceId
            )

            self.partialChain = partialChain

            setupConnection(
                for: partialChain,
                node: request.node,
                networkSetupType: .full
            )
        } catch {
            guard let parseError = error as? CustomNetworkBaseInteractorError else {
                return
            }

            presenter?.didReceive(parseError)
        }
    }

    func setupChain(with request: CustomNetwork.SetupRequest) {
        let evmChainId: UInt64? = if let chainId = request.chainId, let intChainId = Int(chainId) {
            UInt64(intChainId)
        } else {
            nil
        }

        let node = createNode(
            with: request.url,
            name: Constants.defaultCustomNodeName,
            for: nil
        )

        let explorer = createExplorer(
            from: request.blockExplorerURL,
            chainName: request.name
        )

        let options: [LocalChainOptions]? = request.networkType == .evm
            ? [.ethereumBased, .noSubstrateRuntime]
            : nil

        do {
            let priceId = try extractPriceId(from: request.coingeckoURL)

            let partialChain = PartialCustomChainModel(
                chainId: "",
                url: request.url,
                name: request.name,
                iconUrl: request.iconUrl,
                assets: Set(),
                nodes: [node],
                currencySymbol: request.currencySymbol,
                options: options,
                nodeSwitchStrategy: .roundRobin,
                addressPrefix: evmChainId ?? 0,
                connectionMode: .autoBalanced,
                blockExplorer: explorer,
                mainAssetPriceId: priceId
            )

            self.partialChain = partialChain

            setupConnection(
                for: partialChain,
                node: node,
                networkSetupType: request.networkSetupType
            )
        } catch {
            guard let parseError = error as? CustomNetworkBaseInteractorError else {
                return
            }

            presenter?.didReceive(parseError)
        }
    }

    // MARK: To Override

    func completeSetup() {
        fatalError("Must be overriden by subclass")
    }
}

// MARK: WebSocketEngineDelegate

extension CustomNetworkBaseInteractor: WebSocketEngineDelegate {
    func webSocketDidSwitchURL(_: AnyObject, newUrl _: URL) {}

    func webSocketDidChangeState(
        _ connection: AnyObject,
        from oldState: WebSocketEngine.State,
        to newState: WebSocketEngine.State
    ) {
        handleWebSocketChangeState(
            connection,
            from: oldState,
            to: newState
        )
    }
}

// MARK: Private

private extension CustomNetworkBaseInteractor {
    // MARK: Connection

    func setupConnection(
        for partialChain: PartialCustomChainModel,
        node: ChainNodeModel,
        networkSetupType: CustomNetworkSetupOperationType
    ) {
        do {
            guard NSPredicate.ws.evaluate(with: node.url) else {
                throw NetworkNodeConnectingError.wrongFormat
            }

            let connection = try connectionFactory.createConnection(
                for: node,
                chain: partialChain,
                delegate: self
            )

            currentConnection = connection

            setupNetworkWrapper = customNetworkSetupFactory.createOperation(
                with: partialChain,
                connection: connection,
                node: node,
                type: networkSetupType
            )
        } catch {
            let customNetworkError = CustomNetworkBaseInteractorError(from: error)
            presenter?.didReceive(customNetworkError)
        }
    }

    func handleWebSocketChangeState(
        _ connection: AnyObject,
        from oldState: WebSocketEngine.State,
        to newState: WebSocketEngine.State
    ) {
        guard oldState != newState else { return }

        DispatchQueue.main.async {
            guard
                let chain = self.partialChain,
                let connection = connection as? ChainConnection
            else {
                return
            }

            switch newState {
            case .notConnected:
                self.presenter?.didReceive(
                    .connecting(innerError: .unableToConnect(networkName: chain.name))
                )
                self.currentConnection = nil
            case .waitingReconnection:
                connection.disconnect(true)
            case .connected:
                self.handleConnected()
            default:
                break
            }
        }
    }

    func handleConnected() {
        guard let setupNetworkWrapper else { return }

        executeCancellable(
            wrapper: setupNetworkWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: setupNetworkCancellable,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(chain):
                self?.setupFinishStrategy?.handleSetupFinished(
                    for: chain,
                    output: self?.presenter
                )
            case let .failure(error):
                self?.presenter?.didReceive(.init(from: error))
            }
        }
    }

    // MARK: Optional helpers

    func extractPriceId(from priceUrl: String?) throws -> AssetModel.PriceId? {
        var priceId: AssetModel.PriceId?

        if let priceUrl, !priceUrl.isEmpty {
            let parsedPriceId = priceIdParser.parsePriceId(from: priceUrl)

            guard let parsedPriceId else {
                throw CustomNetworkBaseInteractorError.invalidPriceUrl
            }

            priceId = parsedPriceId
        }

        return priceId
    }

    func createExplorer(
        from url: String?,
        chainName: String
    ) -> ChainModel.Explorer? {
        guard
            let url,
            NSPredicate.urlPredicate.evaluate(with: url)
        else {
            return nil
        }

        let trimmedUrl = trimUrlPath(urlString: url)

        let explorer: ChainModel.Explorer? = if checkExplorer(urlString: trimmedUrl, with: .subscan) {
            ChainModel.Explorer(
                name: Constants.subscan,
                account: [trimmedUrl, Constants.subscanAccountPath].joined(with: .slash),
                extrinsic: [trimmedUrl, Constants.subscanExtrinsicPath].joined(with: .slash),
                event: nil
            )
        } else if checkExplorer(urlString: trimmedUrl, with: .statescan) {
            ChainModel.Explorer(
                name: Constants.statescan,
                account: [trimmedUrl, Constants.statescanAccountPath].joined(with: .slash),
                extrinsic: [trimmedUrl, Constants.statescanExtrinsicPath].joined(with: .slash),
                event: [trimmedUrl, Constants.statescanEventPath].joined(with: .slash)
            )
        } else {
            ChainModel.Explorer(
                name: [chainName, Constants.defaultExplorer].joined(with: .space),
                account: [trimmedUrl, Constants.etherscanAccountURL].joined(with: .slash),
                extrinsic: [trimmedUrl, Constants.etherscanExtrinsicURL].joined(with: .slash),
                event: nil
            )
        }

        return explorer
    }

    func checkExplorer(
        urlString: String,
        with pattern: BlockExplorerPatterns
    ) -> Bool {
        let regex = try? NSRegularExpression(
            pattern: pattern.rawValue,
            options: .caseInsensitive
        )

        let range = NSRange(location: 0, length: urlString.utf16.count)
        if regex?.firstMatch(in: urlString, options: [], range: range) != nil {
            return true
        } else {
            return false
        }
    }

    func trimUrlPath(urlString: String) -> String {
        var urlComponents = URLComponents(
            url: URL(string: urlString)!,
            resolvingAgainstBaseURL: false
        )
        urlComponents?.path = ""
        urlComponents?.queryItems = []
        urlComponents?.fragment = nil

        let trimmedUrlString = urlComponents?
            .url?
            .absoluteString
            .trimmingCharacters(in: CharacterSet(charactersIn: "?/").union(CharacterSet.whitespaces))

        return trimmedUrlString ?? urlString
    }
}

// MARK: Constants

private extension CustomNetworkBaseInteractor {
    enum Constants {
        static let subscan = "Subscan"
        static let subscanAccountPath = "account/{address}"
        static let subscanExtrinsicPath = "extrinsic/{hash}"

        static let statescan = "Statescan"
        static let statescanAccountPath = "#/accounts/{address}"
        static let statescanExtrinsicPath = "#/extrinsic/{hash}"
        static let statescanEventPath = "#/events/{event}"

        static let defaultExplorer = "Default Explorer"
        static let etherscanAccountURL = "address/{address}"
        static let etherscanExtrinsicURL = "tx/{hash}"

        static let defaultCustomNodeName = "My custom node"

        static let defaultEVMAssetPrecision: UInt16 = 18
    }
}

// MARK: Regex patterns

private extension CustomNetworkBaseInteractor {
    enum BlockExplorerPatterns: String {
        case subscan = #"^https:\/\/([a-zA-Z0-9-]+\.)*subscan\.io$"#
        case statescan = #"^https:\/\/([a-zA-Z0-9-]+\.)*statescan\.io$"#
        case etherscan = #"etherscan"#
    }
}
