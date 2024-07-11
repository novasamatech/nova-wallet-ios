import SubstrateSdk
import Operation_iOS

final class CustomNetworkEditInteractor: CustomNetworkBaseInteractor {
    private let networkToEdit: ChainModel
    private let selectedNode: ChainNodeModel

    init(
        networkToEdit: ChainModel,
        selectedNode: ChainNodeModel,
        chainRegistry: ChainRegistryProtocol,
        customNetworkSetupFactory: CustomNetworkSetupFactoryProtocol,
        connectionFactory: ConnectionFactoryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        priceIdParser: PriceUrlParserProtocol,
        operationQueue: OperationQueue
    ) {
        self.networkToEdit = networkToEdit
        self.selectedNode = selectedNode

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
        presenter?.didReceive(
            knownChain: networkToEdit,
            selectedNode: selectedNode
        )
    }
}

// MARK: CustomNetworkAddInteractorInputProtocol

extension CustomNetworkEditInteractor: CustomNetworkEditInteractorInputProtocol {
    func editNetwork(with request: CustomNetwork.EditRequest) {
        setupFinishStrategy = CustomNetworkEditStrategy(
            networkToEdit: networkToEdit,
            selectedNode: selectedNode,
            repository: repository,
            operationQueue: operationQueue
        )

        let setupRequest = CustomNetwork.SetupRequest(
            from: request,
            networkType: networkToEdit.isEthereumBased ? .evm : .substrate,
            iconUrl: networkToEdit.icon,
            replacingNode: selectedNode,
            networkSetupType: .full
        )

        setupChain(with: setupRequest)
    }
}
