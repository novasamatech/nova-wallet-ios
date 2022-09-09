import Foundation
import BigInt
import RobinHood
import SubstrateSdk

protocol ParaStkYieldBoostOperationFactoryProtocol {
    func createAutocompoundParamsOperation(
        for connection: JSONRPCEngine,
        request: ParaStkYieldBoostRequest
    ) -> CompoundOperationWrapper<ParaStkYieldBoostResponse>
}

final class ParaStkYieldBoostOperationFactory: ParaStkYieldBoostOperationFactoryProtocol {
    enum RPCMethods {
        static let calculateOptimalAutostaking = "automationTime_calculateOptimalAutostaking"
    }

    func createAutocompoundParamsOperation(
        for connection: JSONRPCEngine,
        request: ParaStkYieldBoostRequest
    ) -> CompoundOperationWrapper<ParaStkYieldBoostResponse> {
        let operation: JSONRPCOperation<ParaStkYieldBoostRequest, ParaStkYieldBoostResponse> = JSONRPCOperation(
            engine: connection,
            method: RPCMethods.calculateOptimalAutostaking,
            parameters: request
        )

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
