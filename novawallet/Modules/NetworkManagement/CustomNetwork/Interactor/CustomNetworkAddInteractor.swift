import SubstrateSdk
import Operation_iOS

final class CustomNetworkAddInteractor: CustomNetworkBaseInteractor {
    private var networkToAdd: ChainModel?

    init(
        networkToAdd: ChainModel?,
        chainRegistry: ChainRegistryProtocol,
        runtimeFetchOperationFactory: RuntimeFetchOperationFactoryProtocol,
        runtimeTypeRegistryFactory: RuntimeTypeRegistryFactoryProtocol,
        blockHashOperationFactory: BlockHashOperationFactoryProtocol,
        systemPropertiesOperationFactory: SystemPropertiesOperationFactoryProtocol,
        connectionFactory: ConnectionFactoryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.networkToAdd = networkToAdd

        super.init(
            chainRegistry: chainRegistry,
            runtimeFetchOperationFactory: runtimeFetchOperationFactory,
            runtimeTypeRegistryFactory: runtimeTypeRegistryFactory,
            blockHashOperationFactory: blockHashOperationFactory,
            systemPropertiesOperationFactory: systemPropertiesOperationFactory,
            connectionFactory: connectionFactory,
            repository: repository,
            operationQueue: operationQueue
        )
    }

    override func handleSetupFinished(for network: ChainModel) {
        let saveOperation = repository.saveOperation(
            { [network] },
            { [] }
        )

        execute(
            operation: saveOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.didFinishWorkWithNetwork()
            case .failure:
                self?.presenter?.didReceive(
                    .common(innerError: .dataCorruption)
                )
            }
        }
    }

    override func completeSetup() {
        guard let networkToAdd, let node = networkToAdd.nodes.first else {
            return
        }

        presenter?.didReceive(
            chain: networkToAdd,
            selectedNode: node
        )
    }
}

// MARK: CustomNetworkAddInteractorInputProtocol

extension CustomNetworkAddInteractor: CustomNetworkAddInteractorInputProtocol {
    func addNetwork(
        networkType: ChainType,
        url: String,
        name: String,
        currencySymbol: String,
        chainId: String?,
        blockExplorerURL: String?,
        coingeckoURL: String?
    ) {
        let type: ChainType = if let networkToAdd {
            networkToAdd.isEthereumBased ? .evm : .substrate
        } else {
            networkType
        }

        connectToChain(
            with: type,
            url: url,
            name: name,
            iconUrl: networkToAdd?.icon,
            currencySymbol: currencySymbol,
            chainId: chainId,
            blockExplorerURL: blockExplorerURL,
            coingeckoURL: coingeckoURL
        )
    }
}
