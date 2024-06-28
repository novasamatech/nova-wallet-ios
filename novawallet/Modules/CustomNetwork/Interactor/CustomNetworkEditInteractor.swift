import SubstrateSdk
import Operation_iOS

final class CustomNetworkEditInteractor: CustomNetworkBaseInteractor {
    weak var presenter: CustomNetworkEditInteractorOutputProtocol? {
        didSet {
            basePresenter = presenter
        }
    }
    
    private let networkToEdit: ChainModel
    
    init(
        networkToEdit: ChainModel,
        chainRegistry: ChainRegistryProtocol,
        blockHashOperationFactory: BlockHashOperationFactoryProtocol,
        connectionFactory: ConnectionFactoryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.networkToEdit = networkToEdit
        
        super.init(
            chainRegistry: chainRegistry,
            blockHashOperationFactory: blockHashOperationFactory,
            connectionFactory: connectionFactory,
            repository: repository,
            operationQueue: operationQueue
        )
    }
    
    override func handleSetupFinished(for network: ChainModel) {
        let saveOperation = repository.saveOperation(
            { [network] },
            { [weak self] in
                guard let self else { return [] }
                
                [networkToEdit.chainId]
            }
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
                self?.presenter?.didReceive(.common(error: .dataCorruption))
            }
        }
    }
    
    override func completeSetup() {
        presenter?.didReceive(chain: networkToEdit)
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
            coingeckoURL: coingeckoURL
        )
    }
}

