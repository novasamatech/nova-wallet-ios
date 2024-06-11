import RobinHood
import SubstrateSdk

enum NodeConnectionMeasureOperationError: Error {
    case noMessage
}

final class NodeConnectionMeasureOperation: BaseOperation<MeasuredNode> {
    private let connectionFactory: ConnectionFactoryProtocol
    private let chain: ChainModel
    private let node: ChainNodeModel

    public init(
        connectionFactory: ConnectionFactoryProtocol,
        chain: ChainModel,
        node: ChainNodeModel
    ) {
        self.connectionFactory = connectionFactory
        self.chain = chain
        self.node = node
    }

    override public func main() {
        super.main()

//        if isCancelled {
//            return
//        }
//
//        if result != nil {
//            return
//        }
//
//        let connection = connectionFactory.createConnection(
//            for: node,
//            chain: chain,
//            delegate: nil
//        )
    }
}

struct MeasuredNode {
    enum ConnectionState {
        case connecting
        case connected(ping: TimeInterval)
    }

    let connectionState: ConnectionState
    let node: ChainNodeModel
}
