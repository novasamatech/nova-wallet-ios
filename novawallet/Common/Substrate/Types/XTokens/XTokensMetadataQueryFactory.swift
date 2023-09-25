import Foundation
import RobinHood
import SubstrateSdk

protocol XTokensMetadataQueryFactoryProtocol {
    func createModuleNameResolutionWrapper(
        for runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<String>
}

final class XTokensMetadataQueryFactory: XcmBaseMetadataQueryFactory, XTokensMetadataQueryFactoryProtocol {
    func createModuleNameResolutionWrapper(
        for runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<String> {
        createModuleNameResolutionWrapper(
            for: runtimeProvider,
            possibleNames: XTokens.possibleModuleNames
        )
    }
}
