import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

protocol XcmPalletMetadataQueryFactoryProtocol {
    func createModuleNameResolutionWrapper(
        for runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<String>

    func createLowestXcmVersionWrapper(
        for runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<Xcm.Version>

    func createXcmMessageTypeResolutionWrapper(
        for runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<String?>
}

final class XcmPalletMetadataQueryFactory: XcmBaseMetadataQueryFactory {}

extension XcmPalletMetadataQueryFactory: XcmPalletMetadataQueryFactoryProtocol {
    func createLowestXcmVersionWrapper(
        for runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<Xcm.Version> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let xcmMessageTypeWrapper = createXcmMessageTypeResolutionWrapper(for: runtimeProvider)

        let resolutionOperation = ClosureOperation<Xcm.Version> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            guard
                let xcmType = try xcmMessageTypeWrapper.targetOperation.extractNoCancellableResultData(),
                let node = codingFactory.getTypeNode(for: xcmType),
                let versionNode = node as? SiVariantNode else {
                throw XcmMetadataQueryError.noXcmTypeFound
            }

            guard
                let version = versionNode.typeMapping
                .compactMap({ Xcm.Version(rawName: $0.name) })
                .min() else {
                throw XcmMetadataQueryError.noXcmVersionFound
            }

            return version
        }

        resolutionOperation.addDependency(codingFactoryOperation)
        resolutionOperation.addDependency(xcmMessageTypeWrapper.targetOperation)

        return xcmMessageTypeWrapper
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: resolutionOperation)
    }

    func createModuleNameResolutionWrapper(
        for runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<String> {
        createModuleNameResolutionWrapper(
            for: runtimeProvider,
            possibleNames: Xcm.possibleModuleNames
        )
    }

    func createXcmMessageTypeResolutionWrapper(
        for runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<String?> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let moduleResolutionWrapper = createModuleNameResolutionWrapper(for: runtimeProvider)

        let resultOperation = ClosureOperation<String?> {
            let palletName = try moduleResolutionWrapper.targetOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let callPath = CallCodingPath(moduleName: palletName, callName: Xcm.executeCallName)
            let argName = Xcm.ExecuteCall<BigUInt>.CodingKeys.message.rawValue
            return codingFactory.getCall(for: callPath)?.mapOptionalArgumentTypeOf(
                argName,
                closure: { $0 }
            )
        }

        resultOperation.addDependency(codingFactoryOperation)
        resultOperation.addDependency(moduleResolutionWrapper.targetOperation)

        return moduleResolutionWrapper
            .insertingHead(
                operations: [codingFactoryOperation]
            )
            .insertingTail(operation: resultOperation)
    }
}
