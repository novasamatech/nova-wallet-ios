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

    func createLowestXcmAssetIdVersionWrapper(
        for runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<Xcm.Version>

    func createXcmMessageTypeResolutionWrapper(
        for runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<String?>
}

final class XcmPalletMetadataQueryFactory: XcmBaseMetadataQueryFactory {}

private extension XcmPalletMetadataQueryFactory {
    func createXcmVersionResolutionOperation(
        dependingOn typeOperation: BaseOperation<String?>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<Xcm.Version> {
        ClosureOperation<Xcm.Version> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            guard
                let xcmType = try typeOperation.extractNoCancellableResultData(),
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
    }
}

extension XcmPalletMetadataQueryFactory: XcmPalletMetadataQueryFactoryProtocol {
    func createLowestXcmVersionWrapper(
        for runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<Xcm.Version> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let xcmMessageTypeWrapper = createXcmMessageTypeResolutionWrapper(for: runtimeProvider)

        let resolutionOperation = createXcmVersionResolutionOperation(
            dependingOn: xcmMessageTypeWrapper.targetOperation,
            codingFactoryOperation: codingFactoryOperation
        )

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

    func createLowestXcmAssetIdVersionWrapper(
        for runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<Xcm.Version> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let moduleResolutionWrapper = createModuleNameResolutionWrapper(for: runtimeProvider)

        let typeOperation = ClosureOperation<String?> {
            let palletName = try moduleResolutionWrapper.targetOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let callPath = CallCodingPath(moduleName: palletName, callName: Xcm.TransferAssetsUsingTypeAndThen.callName)
            let argName = Xcm.TransferAssetsUsingTypeAndThen.CodingKeys.remoteFeesId.rawValue
            return codingFactory.getCall(for: callPath)?.mapOptionalArgumentTypeOf(
                argName,
                closure: { $0 }
            )
        }

        typeOperation.addDependency(codingFactoryOperation)
        typeOperation.addDependency(moduleResolutionWrapper.targetOperation)

        let resolutionOperation = createXcmVersionResolutionOperation(
            dependingOn: typeOperation,
            codingFactoryOperation: codingFactoryOperation
        )

        resolutionOperation.addDependency(typeOperation)

        return moduleResolutionWrapper
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: typeOperation)
            .insertingTail(operation: resolutionOperation)
    }
}
