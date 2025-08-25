import Foundation
import Operation_iOS
import SubstrateSdk

class SubstrateRuntimeApiOperationFactory {
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let stateCallFactory = StateCallRequestFactory()

    init(chainRegistry: ChainRegistryProtocol, operationQueue: OperationQueue) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }
}

enum SubstrateRuntimeApiOperationFactoryError: Error {
    case unexpectedParamsCount
}

extension SubstrateRuntimeApiOperationFactory {
    func createRuntimeCallWrapper<R: Decodable>(
        for chainId: ChainModel.Id,
        path: StateCallPath,
        blockHash: BlockHash? = nil,
        paramsClosure: StateCallWithApiParamsClosure?
    ) -> CompoundOperationWrapper<R> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)
            let connection = try chainRegistry.getConnectionOrError(for: chainId)

            return stateCallFactory.createWrapper(
                path: path,
                paramsClosure: paramsClosure,
                runtimeProvider: runtimeProvider,
                connection: connection,
                operationQueue: operationQueue,
                at: blockHash
            )
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
