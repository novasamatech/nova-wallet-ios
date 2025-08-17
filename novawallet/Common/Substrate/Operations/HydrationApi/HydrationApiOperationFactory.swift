import Foundation
import SubstrateSdk
import Operation_iOS

protocol HydrationApiOperationFactoryProtocol {
    func createCurrencyBalanceWrapper(
        for assetId: @escaping () throws -> HydraDx.AssetId,
        chainId: ChainModel.Id,
        accountId: AccountId
    ) -> CompoundOperationWrapper<HydrationApi.CurrencyData>
}

final class HydrationApiOperationFactory: SubstrateRuntimeApiOperationFactory {}

extension HydrationApiOperationFactory: HydrationApiOperationFactoryProtocol {
    func createCurrencyBalanceWrapper(
        for assetIdClosure: @escaping () throws -> HydraDx.AssetId,
        chainId: ChainModel.Id,
        accountId: AccountId
    ) -> CompoundOperationWrapper<HydrationApi.CurrencyData> {
        createRuntimeCallWrapper(
            for: chainId,
            path: HydrationApi.currenciesAccountPath
        ) { runtimeApi, encoder, context in
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
        }
    }
}
