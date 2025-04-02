import Foundation
import SubstrateSdk
import Operation_iOS

protocol XcmPaymentOperationFactoryProtocol {
    func queryMessageWeight(
        for message: Xcm.Message,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<XcmPayment.WeightResult>
}

final class XcmPaymentOperationFactory {
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let stateCallFactory = StateCallRequestFactory()

    init(chainRegistry: ChainRegistryProtocol, operationQueue: OperationQueue) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }
}

private extension XcmPaymentOperationFactory {
    // TODO: This a duplicate for the method in DryRun
    func createXcmPaymentWrapper<R: Decodable>(
        for chainId: ChainModel.Id,
        method: String,
        paramsClosure: StateCallWithApiParamsClosure?
    ) -> CompoundOperationWrapper<R> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)
            let connection = try chainRegistry.getConnectionOrError(for: chainId)

            let path = StateCallPath(module: XcmPayment.apiName, method: method)

            return stateCallFactory.createWrapper(
                path: path,
                paramsClosure: paramsClosure,
                runtimeProvider: runtimeProvider,
                connection: connection,
                operationQueue: operationQueue
            )
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}

extension XcmPaymentOperationFactory: XcmPaymentOperationFactoryProtocol {
    func queryMessageWeight(
        for message: Xcm.Message,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<XcmPayment.WeightResult> {
        createXcmPaymentWrapper(
            for: chainId,
            method: "query_xcm_weight"
        ) { runtimeApi, encoder, context in
            let paramsCount = runtimeApi.method.inputs.count
            guard paramsCount == 1 else {
                throw DryRunOperationFactoryError.unexpectedParamsCount
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
