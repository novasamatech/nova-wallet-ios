import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class XcmTypeBasedCallDerivator {
    let chainRegistry: ChainRegistryProtocol

    private lazy var xcmModelFactory = XcmModelFactory()
    private lazy var xcmPalletQueryFactory = XcmPalletMetadataQueryFactory()
    private lazy var xTokensQueryFactory = XTokensMetadataQueryFactory()

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }
}

private extension XcmTypeBasedCallDerivator {
    func createTransferAssetsUsingTypeAndThen(
        for request: XcmUnweightedTransferRequest,
        dependingOn moduleResolutionOperation: BaseOperation<String>,
        destinationAssetOperation: BaseOperation<XcmMultilocationAsset>
    ) -> CompoundOperationWrapper<RuntimeCallCollecting> {
        let mapOperation = ClosureOperation<RuntimeCallCollecting> {
            let module = try moduleResolutionOperation.extractNoCancellableResultData()
            let destinationAsset = try destinationAssetOperation.extractNoCancellableResultData()
            let xcmVersion = destinationAsset.beneficiary.version

            let beneficiaryAccount = destinationAsset.beneficiary.map { $0.lastItemLocation() }
            let destination = destinationAsset.beneficiary.map { $0.dropingLastItem() }

            let transferType = Xcm.TransferType(
                transferTypeWithRelativeLocation: request.deriveXcmTransferType(),
                version: xcmVersion
            )

            let feeAssetId = destinationAsset.asset.map(\.assetId)

            let xcmOnDestination = XcmUni.VersionedMessage(
                entity: [
                    XcmUni.Instruction.depositAsset(
                        XcmUni.DepositAssetValue(
                            assets: .wild(.singleCounted),
                            beneficiary: beneficiaryAccount.entity
                        )
                    )
                ],
                version: xcmVersion
            )

            let call = Xcm.TransferAssetsUsingTypeAndThen(
                destination: destination,
                assets: destinationAsset.asset.toVersionedAssets(),
                assetsTransferType: transferType,
                remoteFeesId: feeAssetId,
                feesTransferType: transferType,
                customXcmOnDest: xcmOnDestination,
                weightLimit: .unlimited
            ).runtimeCall(for: module)

            return RuntimeCallCollector(call: call)
        }

        return CompoundOperationWrapper(targetOperation: mapOperation)
    }

    func createPalletXcmTransferMapping(
        dependingOn moduleResolutionOperation: BaseOperation<String>,
        callPathFactory: @escaping (String) -> CallCodingPath,
        destinationAssetOperation: BaseOperation<XcmMultilocationAsset>
    ) -> CompoundOperationWrapper<RuntimeCallCollecting> {
        let mapOperation = ClosureOperation<RuntimeCallCollecting> {
            let module = try moduleResolutionOperation.extractNoCancellableResultData()
            let destinationAsset = try destinationAssetOperation.extractNoCancellableResultData()

            let beneficiaryAccount = destinationAsset.beneficiary.map { $0.lastItemLocation() }
            let destination = destinationAsset.beneficiary.map { $0.dropingLastItem() }

            let callPath = callPathFactory(module)

            let call = Xcm.PalletTransferCall(
                destination: destination,
                beneficiary: beneficiaryAccount,
                assets: destinationAsset.asset.toVersionedAssets(),
                feeAssetItem: 0,
                weightLimit: .unlimited
            ).runtimeCall(for: callPath)

            return RuntimeCallCollector(call: call)
        }

        return CompoundOperationWrapper(targetOperation: mapOperation)
    }

    func createOrmlTransferMapping(
        dependingOn moduleResolutionOperation: BaseOperation<String>,
        destinationAssetOperation: BaseOperation<XcmMultilocationAsset>,
        transferMetadata: XcmTransferMetadata,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<RuntimeCallCollecting> {
        let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let mapOperation = ClosureOperation<RuntimeCallCollecting> {
            let module = try moduleResolutionOperation.extractNoCancellableResultData()
            let codingFactory = try coderFactoryOperation.extractNoCancellableResultData()
            let destination = try destinationAssetOperation.extractNoCancellableResultData()

            return try XTokens.appendTransferCall(
                asset: destination.asset,
                destination: destination.beneficiary,
                module: module,
                weightOption: transferMetadata.fee,
                codingFactory: codingFactory
            )
        }

        mapOperation.addDependency(coderFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [coderFactoryOperation]
        )
    }

    func createTransferMappingWrapper(
        dependingOn moduleResolutionOperation: BaseOperation<String>,
        destinationAssetOperation: BaseOperation<XcmMultilocationAsset>,
        transferRequest: XcmUnweightedTransferRequest,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<RuntimeCallCollecting> {
        switch transferRequest.metadata.callType {
        case .xtokens:
            return createOrmlTransferMapping(
                dependingOn: moduleResolutionOperation,
                destinationAssetOperation: destinationAssetOperation,
                transferMetadata: transferRequest.metadata,
                runtimeProvider: runtimeProvider
            )
        case .xcmpallet:
            return createPalletXcmTransferMapping(
                dependingOn: moduleResolutionOperation,
                callPathFactory: { Xcm.limitedReserveTransferAssetsPath(for: $0) },
                destinationAssetOperation: destinationAssetOperation
            )
        case .teleport:
            return createPalletXcmTransferMapping(
                dependingOn: moduleResolutionOperation,
                callPathFactory: { Xcm.limitedTeleportAssetsPath(for: $0) },
                destinationAssetOperation: destinationAssetOperation
            )
        case .xcmpalletTransferAssets:
            return createTransferAssetsUsingTypeAndThen(
                for: transferRequest,
                dependingOn: moduleResolutionOperation,
                destinationAssetOperation: destinationAssetOperation
            )
        case .unknown:
            return .createWithError(XcmCallTypeError.unknownType)
        }
    }

    func createModuleResolutionWrapper(
        for transferType: XcmCallType,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<String> {
        switch transferType {
        case .xtokens:
            return xTokensQueryFactory.createModuleNameResolutionWrapper(for: runtimeProvider)
        case .xcmpallet, .teleport, .xcmpalletTransferAssets:
            return xcmPalletQueryFactory.createModuleNameResolutionWrapper(for: runtimeProvider)
        case .unknown:
            return CompoundOperationWrapper.createWithError(XcmCallTypeError.unknownType)
        }
    }

    func createMultilocationAssetWrapper(
        for request: XcmUnweightedTransferRequest,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<XcmMultilocationAsset> {
        let versionWrapper = xcmPalletQueryFactory.createLowestXcmVersionWrapper(for: runtimeProvider)

        let resultOperation = ClosureOperation<XcmMultilocationAsset> { [xcmModelFactory] in
            let version = try versionWrapper.targetOperation.extractNoCancellableResultData()
            return try xcmModelFactory.createMultilocationAsset(
                for: .init(
                    origin: request.origin,
                    reserve: request.reserve,
                    destination: request.destination,
                    amount: request.amount,
                    metadata: request.metadata
                ),
                version: version
            )
        }

        resultOperation.addDependency(versionWrapper.targetOperation)

        return versionWrapper.insertingTail(operation: resultOperation)
    }
}

extension XcmTypeBasedCallDerivator: XcmCallDerivating {
    func createTransferCallDerivationWrapper(
        for transferRequest: XcmUnweightedTransferRequest
    ) -> CompoundOperationWrapper<RuntimeCallCollecting> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(
                for: transferRequest.originChain.chainId
            )

            let destinationAssetWrapper = createMultilocationAssetWrapper(
                for: transferRequest,
                runtimeProvider: runtimeProvider
            )

            let moduleResolutionWrapper = createModuleResolutionWrapper(
                for: transferRequest.metadata.callType,
                runtimeProvider: runtimeProvider
            )

            let mapWrapper = createTransferMappingWrapper(
                dependingOn: moduleResolutionWrapper.targetOperation,
                destinationAssetOperation: destinationAssetWrapper.targetOperation,
                transferRequest: transferRequest,
                runtimeProvider: runtimeProvider
            )

            mapWrapper.addDependency(wrapper: moduleResolutionWrapper)
            mapWrapper.addDependency(wrapper: destinationAssetWrapper)

            return mapWrapper
                .insertingHead(operations: moduleResolutionWrapper.allOperations)
                .insertingHead(operations: destinationAssetWrapper.allOperations)
        } catch {
            return .createWithError(error)
        }
    }
}
