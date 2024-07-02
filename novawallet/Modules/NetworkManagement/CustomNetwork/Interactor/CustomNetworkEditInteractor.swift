import SubstrateSdk
import Operation_iOS

final class CustomNetworkEditInteractor: CustomNetworkBaseInteractor {
    weak var presenter: CustomNetworkEditInteractorOutputProtocol? {
        didSet {
            basePresenter = presenter
        }
    }
    
    private let networkToEdit: ChainModel
    private let selectedNode: ChainNodeModel
    
    init(
        networkToEdit: ChainModel,
        selectedNode: ChainNodeModel,
        chainRegistry: ChainRegistryProtocol,
        blockHashOperationFactory: BlockHashOperationFactoryProtocol,
        systemPropertiesOperationFactory: SystemPropertiesOperationFactoryProtocol,
        connectionFactory: ConnectionFactoryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.networkToEdit = networkToEdit
        self.selectedNode = selectedNode
        
        super.init(
            chainRegistry: chainRegistry,
            blockHashOperationFactory: blockHashOperationFactory, 
            systemPropertiesOperationFactory: systemPropertiesOperationFactory,
            connectionFactory: connectionFactory,
            repository: repository,
            operationQueue: operationQueue
        )
    }
    
    override func handleSetupFinished(for network: ChainModel) {
        var readyNetwork = network
        
        if network.chainId == networkToEdit.chainId {
            var nodesToAdd = networkToEdit.nodes
            
            if !network.nodes.contains(where: { $0.url == selectedNode.url }) {
                nodesToAdd.remove(selectedNode)
            }
            
            readyNetwork = network.adding(nodes: nodesToAdd)
        }
        
        let deleteIds = network.chainId != networkToEdit.chainId
            ? [networkToEdit.chainId]
            : []
        
        let saveOperation = repository.saveOperation(
            { [readyNetwork] },
            { deleteIds }
        )
        
        execute(
            operation: saveOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.didEditChain()
            case .failure:
                self?.presenter?.didReceive(
                    .common(innerError: .dataCorruption)
                )
            }
        }
    }
    
    override func completeSetup() {
        presenter?.didReceive(
            chain: networkToEdit,
            selectedNode: selectedNode
        )
    }
}

// MARK: CustomNetworkAddInteractorInputProtocol

extension CustomNetworkEditInteractor: CustomNetworkEditInteractorInputProtocol {
    func editNetwork(
        url: String,
        name: String,
        currencySymbol: String,
        chainId: String?,
        blockExplorerURL: String?,
        coingeckoURL: String?
    ) {
        connectToChain(
            with: networkToEdit.isEthereumBased ? .evm : .substrate ,
            url: url,
            name: name,
            currencySymbol: currencySymbol,
            chainId: chainId,
            blockExplorerURL: blockExplorerURL,
            coingeckoURL: coingeckoURL,
            replacingNode: selectedNode
        )
    }
}

