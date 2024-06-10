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

        if isCancelled {
            return
        }

        if result != nil {
            return
        }
        
        let connection = connectionFactory.createConnection(
            for: node,
            chain: chain,
            delegate: nil
        )
        
        

        do {
            let mutex = DispatchSemaphore(value: 0)

            var receivedResult: Result<Data, Error>?

            try connection.send(message: message, deviceId: deviceId) { result in
                receivedResult = result

                mutex.signal()
            }

            _ = mutex.wait(timeout: .distantFuture)

            result = receivedResult
        } catch {
            result = .failure(error)
        }
    }
}

extension NodeConnectionMeasureOperation {
    struct MeasuredNode {
        enum ConnectionState {
            case connecting
            case connected(ping: TimeInterval)
        }
        
        let connectionState: ConnectionState
        let node: ChainNodeModel
    }
}
