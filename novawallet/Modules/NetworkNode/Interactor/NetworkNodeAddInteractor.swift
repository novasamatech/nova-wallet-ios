import Foundation

class NetworkNodeAddInteractor: NetworkNodeBaseInteractor {
    weak var presenter: NetworkNodeAddInteractorOutputProtocol? {
        didSet {
            basePresenter = presenter
        }
    }
    
    override func findExistingNode(
        with url: String,
        in chain: ChainModel
    ) -> ChainNodeModel? {
        chain.nodes.first { $0.url == url }
    }
    
    override func handleConnected() {
        guard
            let currentConnectingNode,
            let chain = chainRegistry.getChain(for: chainId)
        else { return }
        
        let saveOperation = repository.saveOperation(
            { [chain.adding(node: currentConnectingNode)] },
            { [] }
        )
        
        execute(
            operation: saveOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.didAddNode()
            case .failure:
                self?.presenter?.didReceive(.common(error: .dataCorruption))
            }
        }
    }
}

// MARK: NetworkNodeAddInteractorInputProtocol

extension NetworkNodeAddInteractor: NetworkNodeAddInteractorInputProtocol {
    func addNode(
        with url: String,
        name: String
    ) {
        guard 
            let chain = chainRegistry.getChain(for: chainId),
            let node = createNode(
                with: url,
                name: name
            )
        else {
            return
        }
        
        connect(
            to: node,
            chain: chain
        )
    }
}

// MARK: Private

private extension NetworkNodeAddInteractor {
    func createNode(
        with url: String,
        name: String
    ) -> ChainNodeModel? {
        guard let chain = chainRegistry.getChain(for: chainId) else {
            return nil
        }
        
        let currentLastIndex = chain.nodes
            .map { $0.order }
            .max()
        
        let nodeIndex: Int16 = if let currentLastIndex {
            currentLastIndex + 1
        } else {
            0
        }
        
        let node = ChainNodeModel(
            url: url,
            name: name,
            order: nodeIndex,
            features: nil,
            source: .user
        )
        
        return node
    }
}
