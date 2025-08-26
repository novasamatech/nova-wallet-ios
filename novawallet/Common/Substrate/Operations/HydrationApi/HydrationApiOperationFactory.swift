import Foundation
import SubstrateSdk
import Operation_iOS

protocol HydrationApiOperationFactoryProtocol {
    func createCurrencyBalanceWrapper(
        for assetId: @escaping () throws -> HydraDx.AssetId,
        accountId: AccountId,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<HydrationApi.CurrencyData>
}

final class HydrationApiOperationFactory {
    let runtimeConnectionStore: RuntimeConnectionStoring
    let operationQueue: OperationQueue

    let stateCallFactory = StateCallRequestFactory()

    init(runtimeConnectionStore: RuntimeConnectionStoring, operationQueue: OperationQueue) {
        self.runtimeConnectionStore = runtimeConnectionStore
        self.operationQueue = operationQueue
    }
}

extension HydrationApiOperationFactory: HydrationApiOperationFactoryProtocol {
    func createCurrencyBalanceWrapper(
        for assetIdClosure: @escaping () throws -> HydraDx.AssetId,
        accountId: AccountId,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<HydrationApi.CurrencyData> {
        do {
            let runtimeProvider = try runtimeConnectionStore.getRuntimeProvider()
            let connection = try runtimeConnectionStore.getConnection()

            return stateCallFactory.createWrapper(
                path: HydrationApi.currenciesAccountPath,
                paramsClosure: { runtimeApi, encoder, context in
                    let paramsCount = runtimeApi.method.inputs.count
                    guard paramsCount == 2 else {
                        throw SubstrateRuntimeApiOperationFactoryError.unexpectedParamsCount
                    }

                    let assetId = try assetIdClosure()

                    let assetIdType = runtimeApi.method.inputs[0].paramType

                    try encoder.append(
                        StringCodable(wrappedValue: assetId),
                        ofType: assetIdType.asTypeId(),
                        with: context.toRawContext()
                    )

                    let accountIdType = runtimeApi.method.inputs[1].paramType

                    try encoder.append(
                        BytesCodable(wrappedValue: accountId),
                        ofType: accountIdType.asTypeId(),
                        with: context.toRawContext()
                    )
                },
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
