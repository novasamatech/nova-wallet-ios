import Foundation
import RobinHood
import SubstrateSdk

class XcmBaseMetadataQueryFactory {
    func createXcmTypeVersionWrapper(
        for runtimeProvider: RuntimeProviderProtocol,
        typeName: String
    ) -> CompoundOperationWrapper<Xcm.Version?> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let searchOperation = ClosureOperation<Xcm.Version?> {
            guard
                let node = try codingFactoryOperation.extractNoCancellableResultData().getTypeNode(
                    for: typeName
                ) else {
                return nil
            }

            guard let versionNode = node as? SiVariantNode else {
                return nil
            }

            return versionNode.typeMapping
                .compactMap { Xcm.Version(rawName: $0.name) }
                .min()
        }

        searchOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(targetOperation: searchOperation, dependencies: [codingFactoryOperation])
    }

    func createModuleNameResolutionWrapper(
        for runtimeProvider: RuntimeProviderProtocol,
        possibleNames: [String]
    ) -> CompoundOperationWrapper<String> {
        let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let moduleResolutionOperation = ClosureOperation<String> {
            let metadata = try coderFactoryOperation.extractNoCancellableResultData().metadata
            guard let moduleName = possibleNames.first(
                where: { metadata.getModuleIndex($0) != nil }
            ) else {
                throw XcmTransferServiceError.noXcmPalletFound(possibleNames)
            }

            return moduleName
        }

        moduleResolutionOperation.addDependency(coderFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: moduleResolutionOperation,
            dependencies: [coderFactoryOperation]
        )
    }
}
