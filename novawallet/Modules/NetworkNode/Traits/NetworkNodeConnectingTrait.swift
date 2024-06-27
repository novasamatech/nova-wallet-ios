import Foundation
import SubstrateSdk

protocol NetworkNodeConnectingTrait: AnyObject, WebSocketEngineDelegate {
    var chainRegistry: ChainRegistryProtocol { get }
    var connectionFactory: ConnectionFactoryProtocol { get }
    var currentConnectingNode: ChainNodeModel? { get set }
    var currentConnection: ChainConnection? { get set }
    
    func connect(
        to node: ChainNodeModel,
        replacing existingNode: ChainNodeModel?,
        chain: ChainModel,
        urlPredicate: NSPredicate
    ) throws
}

extension NetworkNodeConnectingTrait {
    func connect(
        to node: ChainNodeModel,
        replacing existingNode: ChainNodeModel?,
        chain: ChainModel,
        urlPredicate: NSPredicate
    ) throws {
        if let existingNode = findExistingNode(with: node.url, ignoring: existingNode) {
            throw NetworkNodeBaseInteractorError.alreadyExists(nodeName: existingNode.name)
        }
        
        guard urlPredicate.evaluate(with: node.url) else {
            throw NetworkNodeBaseInteractorError.wrongFormat
        }
        
        currentConnectingNode = node
        
        currentConnection = try connectionFactory.createConnection(
            for: node,
            chain: chain,
            delegate: self
        )
    }
    
    func findExistingNode(
        with url: String,
        ignoring replacedNode: ChainNodeModel? = nil
    ) -> ChainNodeModel? {
        guard let chainIds = chainRegistry.availableChainIds else {
            return nil
        }
        
        return chainIds
            .compactMap { chainRegistry.getChain(for: $0)?.nodes }
            .flatMap { $0 }
            .first { $0.url == url && $0.url != replacedNode?.url }
    }
}
