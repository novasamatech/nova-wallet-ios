import Foundation
import SubstrateSdk
import Operation_iOS

protocol XcmPaymentOperationFactoryProtocol {
    func queryMessageWeight(
        for message: XcmUni.VersionedMessage,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<XcmPayment.WeightResult>

    func hasSupportWrapper(for chainId: ChainModel.Id) -> CompoundOperationWrapper<Bool>
}

class XcmPaymentOperationFactory: SubstrateRuntimeApiOperationFactory {}

private extension XcmPaymentOperationFactory {
    func getWeightQueryPath() -> StateCallPath {
        StateCallPath(module: XcmPayment.apiName, method: "query_xcm_weight")
    }
}

extension XcmPaymentOperationFactory: XcmPaymentOperationFactoryProtocol {
    func queryMessageWeight(
        for message: XcmUni.VersionedMessage,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<XcmPayment.WeightResult> {
        createRuntimeCallWrapper(
            for: chainId,
            path: getWeightQueryPath()
        ) { runtimeApi, encoder, context in
            let paramsCount = runtimeApi.method.inputs.count
            guard paramsCount == 1 else {
                throw SubstrateRuntimeApiOperationFactoryError.unexpectedParamsCount
            }

            let originType = runtimeApi.method.inputs[0].paramType

            try encoder.append(
                message,
                ofType: originType.asTypeId(),
                with: context.toRawContext()
            )
        }
    }

    func hasSupportWrapper(for chainId: ChainModel.Id) -> CompoundOperationWrapper<Bool> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)
            let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let methodPath = getWeightQueryPath()
            let mapOperation = ClosureOperation<Bool> {
                let coderFactory = try coderFactoryOperation.extractNoCancellableResultData()

                let method = coderFactory.metadata.getRuntimeApiMethod(
                    for: methodPath.module,
                    methodName: methodPath.method
                )

                return method != nil
            }

            mapOperation.addDependency(coderFactoryOperation)

            return CompoundOperationWrapper(
                targetOperation: mapOperation,
                dependencies: [coderFactoryOperation]
            )
        } catch {
            return .createWithError(error)
        }
    }
}
