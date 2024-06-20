import Foundation
import Operation_iOS

class NetworkNodeEditInteractor: NetworkNodeBaseInteractor {
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
        chainId: ChainModel.Id,
        repository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.nodeToEdit = nodeToEdit
        
        super.init(
            chainRegistry: chainRegistry,
            connectionFactory: connectionFactory,
            chainId: chainId,
            repository: repository,
            operationQueue: operationQueue
        )
    }
    
    override func completeSetup() {
        super.completeSetup()
        
        presenter?.didReceive(node: nodeToEdit)
    }
    
    override func findExistingNode(
        with url: String,
        in chain: ChainModel
    ) -> ChainNodeModel? {
        chain.nodes.first { $0.url == url && $0.url != nodeToEdit.url }
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
        
        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.presenter?.didEditNode()
            }
        }

        operationQueue.addOperation(saveOperation)
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
        
        connect(
            to: editedNode,
            chain: chain
        )
    }
}
