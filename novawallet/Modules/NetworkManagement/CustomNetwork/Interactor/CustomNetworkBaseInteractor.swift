import SubstrateSdk
import Operation_iOS

class CustomNetworkBaseInteractor: NetworkNodeCreatorTrait,
    NetworkNodeConnectingTrait,
    CustomNetworkSetupTrait {
    weak var presenter: CustomNetworkBaseInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol
    let runtimeFetchOperationFactory: RuntimeFetchOperationFactoryProtocol
    let runtimeTypeRegistryFactory: RuntimeTypeRegistryFactoryProtocol
    let blockHashOperationFactory: BlockHashOperationFactoryProtocol
    let systemPropertiesOperationFactory: SystemPropertiesOperationFactoryProtocol
    let connectionFactory: ConnectionFactoryProtocol
    let repository: AnyDataProviderRepository<ChainModel>
    let priceIdParser: PriceUrlParserProtocol
    let operationQueue: OperationQueue

    var currentConnectingNode: ChainNodeModel?
    var currentConnection: ChainConnection?

    private var partialChain: PartialCustomChainModel?

    init(
        chainRegistry: ChainRegistryProtocol,
        runtimeFetchOperationFactory: RuntimeFetchOperationFactoryProtocol,
        runtimeTypeRegistryFactory: RuntimeTypeRegistryFactoryProtocol,
        blockHashOperationFactory: BlockHashOperationFactoryProtocol,
        systemPropertiesOperationFactory: SystemPropertiesOperationFactoryProtocol,
        connectionFactory: ConnectionFactoryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        priceIdParser: PriceUrlParserProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.runtimeFetchOperationFactory = runtimeFetchOperationFactory
        self.runtimeTypeRegistryFactory = runtimeTypeRegistryFactory
        self.blockHashOperationFactory = blockHashOperationFactory
        self.systemPropertiesOperationFactory = systemPropertiesOperationFactory
        self.connectionFactory = connectionFactory
        self.repository = repository
        self.priceIdParser = priceIdParser
        self.operationQueue = operationQueue
    }

    func setup() {
        completeSetup()
    }

    func modify(
        _ existingNetwork: ChainModel,
        node: ChainNodeModel,
        url: String,
        name: String,
        currencySymbol: String,
        chainId: String?,
        blockExplorerURL: String?,
        coingeckoURL: String?
    ) {
        let mainAsset = existingNetwork.assets.first(where: { $0.assetId == 0 })

        let evmChainId: UInt16? = if let chainId, let intChainId = Int(chainId) {
            UInt16(intChainId)
        } else {
            nil
        }

        var priceId: AssetModel.PriceId?

        do {
            priceId = try extractPriceId(from: coingeckoURL) ?? mainAsset?.priceId
        } catch {
            guard let parseError = error as? CustomNetworkBaseInteractorError else {
                return
            }

            presenter?.didReceive(parseError)
        }

        let partialChain = PartialCustomChainModel(
            chainId: existingNetwork.chainId,
            url: url,
            name: name,
            iconUrl: existingNetwork.icon,
            assets: existingNetwork.assets,
            nodes: existingNetwork.nodes,
            currencySymbol: mainAsset?.symbol ?? currencySymbol,
            options: existingNetwork.options,
            nodeSwitchStrategy: existingNetwork.nodeSwitchStrategy,
            addressPrefix: evmChainId ?? existingNetwork.addressPrefix,
            connectionMode: .autoBalanced,
            blockExplorer: createExplorer(from: blockExplorerURL) ?? existingNetwork.explorers?.first,
            mainAssetPriceId: priceId
        )

        self.partialChain = partialChain

        connect(
            to: node,
            replacingNode: node,
            chain: partialChain,
            urlPredicate: NSPredicate.ws
        )
    }

    func connectToChain(
        with networkType: ChainType,
        url: String,
        name: String,
        iconUrl: URL? = nil,
        currencySymbol: String,
        chainId: String?,
        blockExplorerURL: String?,
        coingeckoURL: String?,
        replacingNode: ChainNodeModel? = nil
    ) {
        let evmChainId: UInt16? = if let chainId, let intChainId = Int(chainId) {
            UInt16(intChainId)
        } else {
            nil
        }

        let node = createNode(
            with: url,
            name: Constants.defaultCustomNodeName,
            for: nil
        )

        let explorer = createExplorer(from: blockExplorerURL)
        let options: [LocalChainOptions]? = networkType == .evm
            ? [.ethereumBased, .noSubstrateRuntime]
            : nil

        var priceId: AssetModel.PriceId?

        do {
            priceId = try extractPriceId(from: coingeckoURL)
        } catch {
            guard let parseError = error as? CustomNetworkBaseInteractorError else {
                return
            }

            presenter?.didReceive(parseError)
        }

        let partialChain = PartialCustomChainModel(
            chainId: "",
            url: url,
            name: name,
            iconUrl: iconUrl,
            assets: Set(),
            nodes: [node],
            currencySymbol: currencySymbol,
            options: options,
            nodeSwitchStrategy: .roundRobin,
            addressPrefix: evmChainId ?? 0,
            connectionMode: .autoBalanced,
            blockExplorer: explorer,
            mainAssetPriceId: priceId
        )

        self.partialChain = partialChain

        connect(
            to: node,
            replacingNode: replacingNode,
            chain: partialChain,
            urlPredicate: NSPredicate.ws
        )
    }

    // MARK: To Override

    func handleSetupFinished(for _: ChainModel) {
        fatalError("Must be overriden by subclass")
    }

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

    func connect(
        to node: ChainNodeModel,
        replacingNode: ChainNodeModel?,
        chain: ChainNodeConnectable,
        urlPredicate: NSPredicate
    ) {
        do {
            try connect(
                to: node,
                replacing: replacingNode,
                chain: chain,
                urlPredicate: urlPredicate
            )
        } catch let NetworkNodeConnectingError.alreadyExists(existingNode, existingChain) {
            if existingChain.source == .user {
                presenter?.didReceive(
                    .alreadyExistCustom(
                        node: existingNode,
                        chain: existingChain
                    )
                )
            } else {
                presenter?.didReceive(
                    .alreadyExistRemote(
                        node: existingNode,
                        chain: existingChain
                    )
                )
            }
        } catch is NetworkNodeCorrespondingError {
            presenter?.didReceive(.invalidChainId)
        } catch NetworkNodeConnectingError.wrongFormat {
            presenter?.didReceive(
                .connecting(innerError: .wrongFormat)
            )
        } catch {
            print(error)
            presenter?.didReceive(
                .common(innerError: .undefined)
            )
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
                let node = self.currentConnectingNode,
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
                self.handleConnected(
                    connection: connection,
                    chain: chain,
                    node: node
                )
            default:
                break
            }
        }
    }

    func handleConnected(
        connection: ChainConnection,
        chain: PartialCustomChainModel,
        node: ChainNodeModel
    ) {
        let setupNetworkWrapper = createSetupNetworkWrapper(
            partialChain: chain,
            rawRuntimeFetchFactory: runtimeFetchOperationFactory,
            blockHashOperationFactory: blockHashOperationFactory,
            systemPropertiesOperationFactory: systemPropertiesOperationFactory,
            typeRegistryFactory: runtimeTypeRegistryFactory,
            connection: connection,
            node: node
        )

        execute(
            wrapper: setupNetworkWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(chain):
                self?.handleSetupFinished(for: chain)
            case let .failure(error as CustomNetworkSetupError):
                switch error {
                case .decimalsNotFound:
                    self?.presenter?.didReceive(.common(innerError: .noDataRetrieved))
                case let .wrongCurrencySymbol(enteredSymbol, actualSymbol):
                    self?.presenter?.didReceive(
                        .wrongCurrencySymbol(
                            enteredSymbol: enteredSymbol,
                            actualSymbol: actualSymbol
                        )
                    )
                }
            default:
                self?.presenter?.didReceive(.common(innerError: .undefined))
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

        static let priceIdSearchRegexPattern = "\\{([^}]*)\\}"
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
