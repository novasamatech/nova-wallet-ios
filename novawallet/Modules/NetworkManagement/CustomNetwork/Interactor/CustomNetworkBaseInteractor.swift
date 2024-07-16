import SubstrateSdk
import Operation_iOS

class CustomNetworkBaseInteractor: NetworkNodeCreatorTrait,
    NetworkNodeConnectingTrait {
    weak var presenter: CustomNetworkBaseInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol
    let customNetworkSetupFactory: CustomNetworkSetupFactoryProtocol
    let connectionFactory: ConnectionFactoryProtocol
    let repository: AnyDataProviderRepository<ChainModel>
    let priceIdParser: PriceUrlParserProtocol
    let operationQueue: OperationQueue

    var currentConnectingNode: ChainNodeModel?
    var currentConnection: ChainConnection?

    var setupNetworkWrapper: CompoundOperationWrapper<ChainModel>?
    var setupFinishStrategy: CustomNetworkSetupFinishStrategy?

    private var partialChain: PartialCustomChainModel?

    init(
        chainRegistry: ChainRegistryProtocol,
        customNetworkSetupFactory: CustomNetworkSetupFactoryProtocol,
        connectionFactory: ConnectionFactoryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        priceIdParser: PriceUrlParserProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.customNetworkSetupFactory = customNetworkSetupFactory
        self.connectionFactory = connectionFactory
        self.repository = repository
        self.priceIdParser = priceIdParser
        self.operationQueue = operationQueue
    }

    func setup() {
        completeSetup()
    }

    func modify(with request: CustomNetwork.ModifyRequest) {
        let mainAsset = request.existingNetwork.assets.first(where: { $0.assetId == 0 })

        let evmChainId: UInt16? = if let chainId = request.chainId, let intChainId = Int(chainId) {
            UInt16(intChainId)
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
                blockExplorer: createExplorer(from: request.blockExplorerURL) ?? request.existingNetwork.explorers?.first,
                mainAssetPriceId: priceId
            )

            self.partialChain = partialChain

            setupConnection(
                for: partialChain,
                node: request.node,
                replacing: request.node,
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
        let evmChainId: UInt16? = if let chainId = request.chainId, let intChainId = Int(chainId) {
            UInt16(intChainId)
        } else {
            nil
        }

        let node = createNode(
            with: request.url,
            name: Constants.defaultCustomNodeName,
            for: nil
        )

        let explorer = createExplorer(from: request.blockExplorerURL)
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
                replacing: request.replacingNode,
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
        replacing existingNode: ChainNodeModel?,
        networkSetupType: CustomNetworkSetupOperationType
    ) {
        do {
            let connection = try connect(
                to: node,
                replacing: existingNode,
                chain: partialChain,
                urlPredicate: NSPredicate.ws
            )

            setupNetworkWrapper = customNetworkSetupFactory.createOperation(
                with: partialChain,
                connection: connection,
                node: node,
                type: networkSetupType
            )

            currentConnection = connection
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

        execute(
            wrapper: setupNetworkWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(chain):
                self?.setupFinishStrategy?.handleSetupFinished(
                    for: chain,
                    presenter: self?.presenter
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

    func createExplorer(from url: String?) -> ChainModel.Explorer? {
        guard let url = url?.trimmingCharacters(
            in: CharacterSet(charactersIn: "/").union(CharacterSet.whitespaces)
        ) else {
            return nil
        }

        let explorer: ChainModel.Explorer? = if checkExplorer(urlString: url, with: .subscan) {
            ChainModel.Explorer(
                name: Constants.subscan,
                account: [url, Constants.subscanAccountPath].joined(with: .slash),
                extrinsic: [url, Constants.subscanExtrinsicPath].joined(with: .slash),
                event: nil
            )
        } else if checkExplorer(urlString: url, with: .statescan) {
            ChainModel.Explorer(
                name: Constants.statescan,
                account: [url, Constants.statescanAccountPath].joined(with: .slash),
                extrinsic: [url, Constants.statescanExtrinsicPath].joined(with: .slash),
                event: [url, Constants.statescanEventPath].joined(with: .slash)
            )
        } else if checkExplorer(urlString: url, with: .etherscan) {
            ChainModel.Explorer(
                name: Constants.etherscan,
                account: Constants.etherscanAccountURL,
                extrinsic: Constants.etherscanExtrinsicURL,
                event: nil
            )
        } else {
            nil
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
        if let match = regex?.firstMatch(in: urlString, options: [], range: range) {
            return match.range.length == urlString.utf16.count
        } else {
            return false
        }
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

        static let etherscan = "Etherscan"
        static let etherscanAccountURL = "https: // etherscan.io/tx/{hash}"
        static let etherscanExtrinsicURL = "https://etherscan.io/tx/{hash}"

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
