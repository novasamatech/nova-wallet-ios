import Foundation
import SubstrateSdk
import Operation_iOS

protocol DryRunOperationFactoryProtocol {
    func createDryRunCallWrapper<C>(
        _ call: RuntimeCall<C>,
        origin: RuntimeCallOrigin,
        xcmVersion: Xcm.Version,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<DryRun.CallResult>

    func createDryRunXcmWrapper(
        from origin: XcmUni.VersionedLocation,
        xcm: XcmUni.VersionedMessage,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<DryRun.XcmResult>
}

final class DryRunOperationFactory: SubstrateRuntimeApiOperationFactory {}

extension DryRunOperationFactory: DryRunOperationFactoryProtocol {
    func createDryRunCallWrapper<C>(
        _ call: RuntimeCall<C>,
        origin: RuntimeCallOrigin,
        xcmVersion: Xcm.Version,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<DryRun.CallResult> {
        createRuntimeCallWrapper(
            for: chainId,
            path: StateCallPath(module: DryRun.apiName, method: "dry_run_call")
        ) { runtimeApi, encoder, context in
            // dry run v2 has additional xcm version param
            let paramsCount = runtimeApi.method.inputs.count
            guard paramsCount == 2 || paramsCount == 3 else {
                throw SubstrateRuntimeApiOperationFactoryError.unexpectedParamsCount
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

            if paramsCount == 3 {
                let xcmVersionType = runtimeApi.method.inputs[2].paramType

                try encoder.append(
                    StringScaleMapper(value: xcmVersion.rawValue),
                    ofType: xcmVersionType.asTypeId(),
                    with: context.toRawContext()
                )
            }
        }
    }

    func createDryRunXcmWrapper(
        from origin: XcmUni.VersionedLocation,
        xcm: XcmUni.VersionedMessage,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<DryRun.XcmResult> {
        createRuntimeCallWrapper(
            for: chainId,
            path: StateCallPath(module: DryRun.apiName, method: "dry_run_xcm")
        ) { runtimeApi, encoder, context in
            guard runtimeApi.method.inputs.count == 2 else {
                throw SubstrateRuntimeApiOperationFactoryError.unexpectedParamsCount
            }

            let originType = runtimeApi.method.inputs[0].paramType

            try encoder.append(
                origin,
                ofType: originType.asTypeId(),
                with: context.toRawContext()
            )

            let xcmType = runtimeApi.method.inputs[1].paramType

            try encoder.append(
                xcm,
                ofType: xcmType.asTypeId(),
                with: context.toRawContext()
            )
        }
    }
}
