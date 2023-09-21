import Foundation
import RobinHood
import SubstrateSdk

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
}
