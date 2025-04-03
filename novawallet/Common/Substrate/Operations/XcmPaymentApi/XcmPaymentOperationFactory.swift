import Foundation
import SubstrateSdk
import Operation_iOS

protocol XcmPaymentOperationFactoryProtocol {
    func queryMessageWeight(
        for message: Xcm.Message,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<XcmPayment.WeightResult>
}

class XcmPaymentOperationFactory: SubstrateRuntimeApiOperationFactory {}

extension XcmPaymentOperationFactory: XcmPaymentOperationFactoryProtocol {
    func queryMessageWeight(
        for message: Xcm.Message,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<XcmPayment.WeightResult> {
        createRuntimeCallWrapper(
            for: chainId,
            path: StateCallPath(module: XcmPayment.apiName, method: "query_xcm_weight")
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
}
