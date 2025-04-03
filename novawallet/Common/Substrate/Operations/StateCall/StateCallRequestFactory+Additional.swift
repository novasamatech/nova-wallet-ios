import Foundation
import Operation_iOS
import SubstrateSdk

typealias StateCallWithApiParamsClosure = (
    RuntimeApiQueryResult,
    DynamicScaleEncoding,
    RuntimeJsonContext
) throws -> Void

extension StateCallRequestFactoryProtocol {
    func createWrapper<V: Decodable>(
        path: StateCallPath,
        paramsClosure: StateCallWithApiParamsClosure?,
        runtimeProvider: RuntimeProviderProtocol,
        connection: JSONRPCEngine,
        operationQueue: OperationQueue,
        at blockHash: BlockHash? = nil
    ) -> CompoundOperationWrapper<V> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<V> = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let runtimeApi = try codingFactory.metadata.getRuntimeApiMethodOrError(
                for: path.module,
                methodName: path.method
            )

            return self.createWrapper(
                for: runtimeApi.callName,
                paramsClosure: { encoder, context in
                    try paramsClosure?(runtimeApi, encoder, context)
                },
                codingFactoryClosure: { codingFactory },
                connection: connection,
                queryType: runtimeApi.method.output.asTypeId(),
                at: blockHash
            )
        }

        wrapper.addDependency(operations: [codingFactoryOperation])

        return wrapper.insertingHead(operations: [codingFactoryOperation])
    }
}
