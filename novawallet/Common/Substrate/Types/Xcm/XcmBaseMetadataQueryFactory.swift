import Foundation
import Operation_iOS
import SubstrateSdk

enum XcmMetadataQueryError: Error {
    case noXcmPalletFound([String])
    case noXcmTypeFound
    case noXcmVersionFound
}

class XcmBaseMetadataQueryFactory {
    func createXcmTypeVersionWrapper(
        for runtimeProvider: RuntimeCodingServiceProtocol,
        oneOfTypes: [String]
    ) -> CompoundOperationWrapper<Xcm.Version?> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let searchOperation = ClosureOperation<Xcm.Version?> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            guard
                let typeName = oneOfTypes.first(where: { codingFactory.hasType(for: $0) }),
                let node = codingFactory.getTypeNode(for: typeName) else {
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
        for runtimeProvider: RuntimeCodingServiceProtocol,
        possibleNames: [String]
    ) -> CompoundOperationWrapper<String> {
        let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let moduleResolutionOperation = ClosureOperation<String> {
            let metadata = try coderFactoryOperation.extractNoCancellableResultData().metadata
            guard let moduleName = possibleNames.first(
                where: { metadata.getModuleIndex($0) != nil }
            ) else {
                throw XcmMetadataQueryError.noXcmPalletFound(possibleNames)
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
