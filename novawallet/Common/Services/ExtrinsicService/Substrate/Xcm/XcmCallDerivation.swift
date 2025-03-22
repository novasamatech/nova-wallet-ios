import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

protocol XcmCallDerivating {
    func createTransferCallDerivationWrapper(
        for transferRequest: XcmUnweightedTransferRequest
    ) -> CompoundOperationWrapper<RuntimeCallCollecting>
}

final class XcmCallDerivator {
    let chainRegistry: ChainRegistryProtocol

    private lazy var xcmModelFactory = XcmModelFactory()
    private lazy var xcmPalletQueryFactory = XcmPalletMetadataQueryFactory()
    private lazy var xTokensQueryFactory = XTokensMetadataQueryFactory()

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }
}

private extension XcmCallDerivator {
    func createPalletXcmTransferMapping(
        dependingOn moduleResolutionOperation: BaseOperation<String>,
        callPathFactory: @escaping (String) -> CallCodingPath,
        destinationAssetOperation: BaseOperation<XcmMultilocationAsset>
    ) -> CompoundOperationWrapper<RuntimeCallCollecting> {
        let mapOperation = ClosureOperation<RuntimeCallCollecting> {
            let module = try moduleResolutionOperation.extractNoCancellableResultData()
            let destinationAsset = try destinationAssetOperation.extractNoCancellableResultData()

            let (destination, beneficiary) = destinationAsset.location.separatingDestinationBenificiary()
            let assets = Xcm.VersionedMultiassets(versionedMultiasset: destinationAsset.asset)

            let callPath = callPathFactory(module)

            let call = Xcm.PalletTransferCall(
                destination: destination,
                beneficiary: beneficiary,
                assets: assets,
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
            let destinationAsset = try destinationAssetOperation.extractNoCancellableResultData()

            let asset = destinationAsset.asset
            let location = destinationAsset.location

            return try XTokens.appendTransferCall(
                asset: asset,
                destination: location,
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

    func createMultilocationAssetWrapper(
        request: XcmUnweightedTransferRequest,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<XcmMultilocationAsset> {
        switch request.metadata.callType {
        case .xtokens:
            // we make an assumption that xtokens pallet maintains the same versions as xcm pallet
            let multiassetVersionWrapper = xcmPalletQueryFactory.createLowestMultiassetVersionWrapper(
                for: runtimeProvider
            )

            return createMultilocationAssetWrapper(
                for: multiassetVersionWrapper,
                request: request,
                runtimeProvider: runtimeProvider
            )
        case .xcmpallet, .teleport, .xcmpalletTransferAssets:
            let multiassetsVersionWrapper = xcmPalletQueryFactory.createLowestMultiassetsVersionWrapper(
                for: runtimeProvider
            )

            return createMultilocationAssetWrapper(
                for: multiassetsVersionWrapper,
                request: request,
                runtimeProvider: runtimeProvider
            )
        case .unknown:
            return .createWithError(XcmTransferTypeError.unknownType)
        }
    }

    func createModuleResolutionWrapper(
        for transferType: XcmTransferType,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<String> {
        switch transferType {
        case .xtokens:
            return xTokensQueryFactory.createModuleNameResolutionWrapper(for: runtimeProvider)
        case .xcmpallet, .teleport, .xcmpalletTransferAssets:
            return xcmPalletQueryFactory.createModuleNameResolutionWrapper(for: runtimeProvider)
        case .unknown:
            return CompoundOperationWrapper.createWithError(XcmTransferTypeError.unknownType)
        }
    }

    func createTransferMappingWrapper(
        dependingOn moduleResolutionOperation: BaseOperation<String>,
        destinationAssetOperation: BaseOperation<XcmMultilocationAsset>,
        transferMetadata: XcmTransferMetadata,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<RuntimeCallCollecting> {
        switch transferMetadata.callType {
        case .xtokens:
            return createOrmlTransferMapping(
                dependingOn: moduleResolutionOperation,
                destinationAssetOperation: destinationAssetOperation,
                transferMetadata: transferMetadata,
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
            return createPalletXcmTransferMapping(
                dependingOn: moduleResolutionOperation,
                callPathFactory: { Xcm.transferAssetsPath(for: $0) },
                destinationAssetOperation: destinationAssetOperation
            )
        case .unknown:
            return .createWithError(XcmTransferTypeError.unknownType)
        }
    }

    func createMultilocationAssetWrapper(
        for multiassetVersionWrapper: CompoundOperationWrapper<Xcm.Version?>,
        request: XcmUnweightedTransferRequest,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<XcmMultilocationAsset> {
        let multilocationVersionWrapper = xcmPalletQueryFactory.createLowestMultilocationVersionWrapper(
            for: runtimeProvider
        )

        let mappingOperation = ClosureOperation<XcmMultilocationAsset> { [xcmModelFactory] in
            let multiassetVersion = try multiassetVersionWrapper.targetOperation.extractNoCancellableResultData()
            let multilocationVersion = try multilocationVersionWrapper.targetOperation
                .extractNoCancellableResultData()

            return try xcmModelFactory.createMultilocationAsset(
                for: .init(
                    origin: request.origin.chainAsset,
                    reserve: request.reserve.chain,
                    destination: request.destination,
                    amount: request.amount,
                    metadata: request.metadata
                ),
                version: .init(multiLocation: multilocationVersion, multiAssets: multiassetVersion)
            )
        }

        mappingOperation.addDependency(multiassetVersionWrapper.targetOperation)
        mappingOperation.addDependency(multilocationVersionWrapper.targetOperation)

        let dependecies = multiassetVersionWrapper.allOperations + multilocationVersionWrapper.allOperations

        return .init(targetOperation: mappingOperation, dependencies: dependecies)
    }
}

extension XcmCallDerivator: XcmCallDerivating {
    func createTransferCallDerivationWrapper(
        for transferRequest: XcmUnweightedTransferRequest
    ) -> CompoundOperationWrapper<RuntimeCallCollecting> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(
                for: transferRequest.originChain.chainId
            )

            let destinationAssetWrapper = createMultilocationAssetWrapper(
                request: transferRequest,
                runtimeProvider: runtimeProvider
            )

            let moduleResolutionWrapper = createModuleResolutionWrapper(
                for: transferRequest.metadata.callType,
                runtimeProvider: runtimeProvider
            )

            let mapWrapper = createTransferMappingWrapper(
                dependingOn: moduleResolutionWrapper.targetOperation,
                destinationAssetOperation: destinationAssetWrapper.targetOperation,
                transferMetadata: transferRequest.metadata,
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
