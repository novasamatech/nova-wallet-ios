import Foundation
import Operation_iOS

final class NetworkNodeEditInteractor: NetworkNodeBaseInteractor {
    weak var presenter: NetworkNodeEditInteractorOutputProtocol? {
        didSet {
            basePresenter = presenter
        }
    }
    
    private let nodeToEdit: ChainNodeModel
    
    init(
        nodeToEdit: ChainNodeModel,
        chainRegistry: any ChainRegistryProtocol,
        connectionFactory: any ConnectionFactoryProtocol,
        blockHashOperationFactory: BlockHashOperationFactoryProtocol,
        chainId: ChainModel.Id,
        repository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.nodeToEdit = nodeToEdit
        
        super.init(
            chainRegistry: chainRegistry,
            connectionFactory: connectionFactory,
            blockHashOperationFactory: blockHashOperationFactory,
            chainId: chainId,
            repository: repository,
            operationQueue: operationQueue
        )
    }
    
    override func completeSetup() {
        super.completeSetup()
        
        presenter?.didReceive(node: nodeToEdit)
    }
    
    override func handleConnected() {
        guard
            let chain = chainRegistry.getChain(for: chainId),
            let editedNode = currentConnectingNode
        else { return }
        
        let saveOperation = repository.saveOperation(
            { [weak self] in
                guard let self else { return [] }
                
                return [chain.replacing(nodeToEdit, with: editedNode)]
            },
            { [] }
        )
        
        execute(
            operation: saveOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.didEditNode()
            case .failure:
                self?.presenter?.didReceive(
                    .common(innerError: .dataCorruption)
                )
            }
        }
    }
}

// MARK: NetworkNodeEditInteractorInputProtocol

extension NetworkNodeEditInteractor: NetworkNodeEditInteractorInputProtocol {
    func editNode(
        with url: String,
        name: String
    ) {
        guard let chain = chainRegistry.getChain(for: chainId) else { return }
        
        let editedNode = nodeToEdit.updating(url, name)
        
        do {
            try connect(
                to: editedNode,
                replacing: nodeToEdit,
                chain: chain,
                urlPredicate: NSPredicate.ws
            )
        } catch {
            guard let networkNodeError = error as? NetworkNodeBaseInteractorError else { return }
            
            presenter?.didReceive(networkNodeError)
        }
    }
}
