import SubstrateSdk
import Operation_iOS

protocol ChainNameOperationFactoryProtocol {
    func createChainNameOperation(connection: JSONRPCEngine) -> BaseOperation<String>
}

class SubstrateChainNameOperationFactory: ChainNameOperationFactoryProtocol {
    func createChainNameOperation(connection: JSONRPCEngine) -> BaseOperation<String> {
        let requestOperation = JSONRPCListOperation<String>(
            engine: connection,
            method: RPCMethod.chain
        )

        return requestOperation
    }
}
