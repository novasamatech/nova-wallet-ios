import Foundation

final class NetworkNodeAddInteractor: NetworkNodeBaseInteractor, NetworkNodeCreatorTrait {
    weak var presenter: NetworkNodeAddInteractorOutputProtocol? {
        didSet {
            basePresenter = presenter
        }
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
                self?.presenter?.didReceive(
                    .common(innerError: .dataCorruption)
                )
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
        guard  let chain = chainRegistry.getChain(for: chainId) else {
            return
        }
        
        let node = createNode(
            with: url,
            name: name,
            for: chain
        )
        
        do {
            try connect(
                to: node,
                replacing: nil,
                chain: chain,
                urlPredicate: NSPredicate.ws
            )
        } catch {
            guard let networkNodeError = error as? NetworkNodeBaseInteractorError else { return }
            
            presenter?.didReceive(networkNodeError)
        }
    }
}
