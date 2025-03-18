import Foundation
import SubstrateSdk
import Operation_iOS

protocol DryRunOperationFactoryProtocol {
    func createDryRunCallWrapper<A>(
        _ call: RuntimeCall<A>,
        origin: RuntimeCallOrigin,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<DryRun.CallResult>
}

enum DryRunOperationFactoryError: Error {
    case unexpectedParamsCount
}

final class DryRunOperationFactory {
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let stateCallFactory = StateCallRequestFactory()

    init(chainRegistry: ChainRegistryProtocol, operationQueue: OperationQueue) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }
}

extension DryRunOperationFactory: DryRunOperationFactoryProtocol {
    func createDryRunCallWrapper<A>(
        _ call: RuntimeCall<A>,
        origin: RuntimeCallOrigin,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<DryRun.CallResult> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)
            let connection = try chainRegistry.getConnectionOrError(for: chainId)

            let path = StateCallPath(module: DryRun.apiName, method: "dry_run_call")

            return stateCallFactory.createWrapper(
                path: path,
                paramsClosure: { runtimeApi, encoder, context in
                    guard runtimeApi.method.inputs.count == 2 else {
                        throw DryRunOperationFactoryError.unexpectedParamsCount
                    }

                    let originType = runtimeApi.method.inputs[0].paramType

                    try encoder.append(
                        origin,
                        ofType: originType.asTypeId(),
                        with: context.toRawContext()
                    )

                    let callType = runtimeApi.method.inputs[1].paramType

                    try encoder.append(
                        call,
                        ofType: callType.asTypeId(),
                        with: context.toRawContext()
                    )
                },
                runtimeProvider: runtimeProvider,
                connection: connection,
                operationQueue: operationQueue
            )
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
