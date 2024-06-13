import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

protocol XcmPalletMetadataQueryFactoryProtocol {
    func createModuleNameResolutionWrapper(
        for runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<String>

    func createLowestMultiassetsVersionWrapper(
        for runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<Xcm.Version?>

    func createLowestMultiassetVersionWrapper(
        for runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<Xcm.Version?>

    func createLowestMultilocationVersionWrapper(
        for runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<Xcm.Version?>

    func createXcmMessageTypeResolutionWrapper(
        for runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<String?>
}

final class XcmPalletMetadataQueryFactory: XcmBaseMetadataQueryFactory, XcmPalletMetadataQueryFactoryProtocol {
    func createLowestMultiassetsVersionWrapper(
        for runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<Xcm.Version?> {
        createXcmTypeVersionWrapper(
            for: runtimeProvider,
            typeName: "xcm.VersionedMultiAssets"
        )
    }

    func createLowestMultiassetVersionWrapper(
        for runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<Xcm.Version?> {
        createXcmTypeVersionWrapper(
            for: runtimeProvider,
            typeName: "xcm.VersionedMultiAsset"
        )
    }

    func createLowestMultilocationVersionWrapper(
        for runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<Xcm.Version?> {
        createXcmTypeVersionWrapper(
            for: runtimeProvider,
            typeName: "xcm.VersionedMultiLocation"
        )
    }

    func createModuleNameResolutionWrapper(
        for runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<String> {
        createModuleNameResolutionWrapper(
            for: runtimeProvider,
            possibleNames: Xcm.possibleModuleNames
        )
    }

    func createXcmMessageTypeResolutionWrapper(
        for runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<String?> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let moduleResolutionWrapper = createModuleNameResolutionWrapper(for: runtimeProvider)

        let resolutionOperation = ClosureOperation<String?> {
            let palletName = try moduleResolutionWrapper.targetOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let callPath = CallCodingPath(moduleName: palletName, callName: Xcm.executeCallName)
            let argName = Xcm.ExecuteCall<BigUInt>.CodingKeys.message.rawValue
            return codingFactory.getCall(for: callPath)?.mapOptionalArgumentTypeOf(
                argName,
                closure: { $0 }
            )
        }

        resolutionOperation.addDependency(codingFactoryOperation)
        resolutionOperation.addDependency(moduleResolutionWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: resolutionOperation,
            dependencies: [codingFactoryOperation] + moduleResolutionWrapper.allOperations
        )
    }
}
