import SubstrateSdk
import Operation_iOS

final class CustomNetworkAddInteractor: CustomNetworkBaseInteractor {
    private var networkToAdd: ChainModel?

    init(
        networkToAdd: ChainModel?,
        chainRegistry: ChainRegistryProtocol,
        customNetworkSetupFactory: CustomNetworkSetupFactoryProtocol,
        connectionFactory: ConnectionFactoryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        priceIdParser: PriceUrlParserProtocol,
        operationQueue: OperationQueue
    ) {
        self.networkToAdd = networkToAdd

        super.init(
            chainRegistry: chainRegistry,
            customNetworkSetupFactory: customNetworkSetupFactory,
            connectionFactory: connectionFactory,
            repository: repository,
            priceIdParser: priceIdParser,
            operationQueue: operationQueue
        )
    }

    override func completeSetup() {
        guard let networkToAdd, let node = networkToAdd.nodes.first else {
            return
        }

        presenter?.didReceive(
            knownChain: networkToAdd,
            selectedNode: node
        )
    }
}

// MARK: CustomNetworkAddInteractorInputProtocol

extension CustomNetworkAddInteractor: CustomNetworkAddInteractorInputProtocol {
    func addNetwork(with request: CustomNetwork.AddRequest) {
        setupFinishStrategy = CustomNetworkAddNewStrategy(
            repository: repository,
            operationQueue: operationQueue
        )

        let type: ChainType = if let networkToAdd {
            networkToAdd.isEthereumBased ? .evm : .substrate
        } else {
            request.networkType
        }

        let setupRequest = CustomNetwork.SetupRequest(
            from: request,
            networkType: type,
            iconUrl: networkToAdd?.icon,
            networkSetupType: .full
        )

        setupChain(with: setupRequest)
    }

    func fetchNetworkProperties(for url: String) {
        setupFinishStrategy = CustomNetworkProvideStrategy()

        let request = CustomNetwork.SetupRequest(
            networkType: .substrate,
            url: url,
            name: "",
            iconUrl: networkToAdd?.icon,
            networkSetupType: .noRuntime
        )

        setupChain(with: request)
    }
}
