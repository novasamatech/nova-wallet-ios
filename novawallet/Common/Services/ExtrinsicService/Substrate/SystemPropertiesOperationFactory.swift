import Operation_iOS
import SubstrateSdk

protocol SystemPropertiesOperationFactoryProtocol {
    func createSystemPropertiesOperation(connection: JSONRPCEngine) -> BaseOperation<SystemProperties>
}

class SystemPropertiesOperationFactory: SystemPropertiesOperationFactoryProtocol {
    func createSystemPropertiesOperation(connection: JSONRPCEngine) -> BaseOperation<SystemProperties> {
        let requestOperation = JSONRPCListOperation<SystemProperties>(
            engine: connection,
            method: RPCMethod.properties
        )

        return requestOperation
    }
}
