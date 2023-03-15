import Foundation
import RobinHood
import BigInt
import SubstrateSdk

extension XcmTransferService {
    func createMultilocationAssetWrapper(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers,
        type: XcmAssetTransfer.TransferType,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<XcmMultilocationAsset> {
        switch type {
        case .xtokens:
            // keep xtokens version to 1 until pallet is updated
            do {
                let multilocationAsset = try xcmFactory.createMultilocationAsset(
                    for: .init(
                        origin: request.origin,
                        reserve: request.reserve.chain,
                        destination: request.destination,
                        amount: request.amount,
                        xcmTransfers: xcmTransfers
                    ),
                    version: .init(multiLocation: .V1, multiAssets: .V1)
                )

                return .createWithResult(multilocationAsset)
            } catch {
                return .createWithError(error)
            }
        case .xcmpallet, .teleport:
            let multiassetsVersionWrapper = metadataQueryFactory.createLowestMultiassetsVersionWrapper(
                for: runtimeProvider
            )

            let multilocationVersionWrapper = metadataQueryFactory.createLowestMultilocationVersionWrapper(
                for: runtimeProvider
            )

            let transferFactory = xcmFactory

            let mappingOperation = ClosureOperation<XcmMultilocationAsset> {
                let multiassetsVersion = try multiassetsVersionWrapper.targetOperation.extractNoCancellableResultData()
                let multilocationVersion = try multilocationVersionWrapper.targetOperation
                    .extractNoCancellableResultData()

                return try transferFactory.createMultilocationAsset(
                    for: .init(
                        origin: request.origin,
                        reserve: request.reserve.chain,
                        destination: request.destination,
                        amount: request.amount,
                        xcmTransfers: xcmTransfers
                    ),
                    version: .init(multiLocation: multilocationVersion, multiAssets: multiassetsVersion)
                )
            }

            mappingOperation.addDependency(multiassetsVersionWrapper.targetOperation)
            mappingOperation.addDependency(multilocationVersionWrapper.targetOperation)

            let dependecies = multiassetsVersionWrapper.allOperations + multilocationVersionWrapper.allOperations

            return .init(targetOperation: mappingOperation, dependencies: dependecies)
        case .unknown:
            return .createWithError(XcmAssetTransfer.TransferTypeError.unknownType)
        }
    }

    func createTransferWrapper(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers,
        maxWeight: BigUInt
    ) -> CompoundOperationWrapper<(ExtrinsicBuilderClosure, CallCodingPath)> {
        let destChainId = request.destination.chain.chainId
        let originChainAssetId = request.origin.chainAssetId
        guard let xcmTransfer = xcmTransfers.transfer(from: originChainAssetId, destinationChainId: destChainId) else {
            let error = XcmTransferFactoryError.noDestinationAssetFound(originChainAssetId)
            return CompoundOperationWrapper.createWithError(error)
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: request.origin.chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let destinationAssetWrapper = createMultilocationAssetWrapper(
            request: request,
            xcmTransfers: xcmTransfers,
            type: xcmTransfer.type,
            runtimeProvider: runtimeProvider
        )

        let moduleResolutionWrapper = createModuleResolutionWrapper(
            for: xcmTransfer.type,
            runtimeProvider: runtimeProvider
        )

        let mapWrapper = createTransferMappingWrapper(
            dependingOn: moduleResolutionWrapper.targetOperation,
            destinationAssetOperation: destinationAssetWrapper.targetOperation,
            xcmTransfer: xcmTransfer,
            maxWeight: maxWeight,
            runtimeProvider: runtimeProvider
        )

        mapWrapper.addDependency(wrapper: moduleResolutionWrapper)
        mapWrapper.addDependency(wrapper: destinationAssetWrapper)

        let dependencies = destinationAssetWrapper.allOperations + moduleResolutionWrapper.allOperations
            + mapWrapper.dependencies

        return CompoundOperationWrapper(targetOperation: mapWrapper.targetOperation, dependencies: dependencies)
    }

    func createTransferMappingWrapper(
        dependingOn moduleResolutionOperation: BaseOperation<String>,
        destinationAssetOperation: BaseOperation<XcmMultilocationAsset>,
        xcmTransfer: XcmAssetTransfer,
        maxWeight: BigUInt,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<(ExtrinsicBuilderClosure, CallCodingPath)> {
        switch xcmTransfer.type {
        case .xtokens:
            let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let mapOperation = ClosureOperation<(ExtrinsicBuilderClosure, CallCodingPath)> {
                let module = try moduleResolutionOperation.extractNoCancellableResultData()
                let codingFactory = try coderFactoryOperation.extractNoCancellableResultData()
                let destinationAsset = try destinationAssetOperation.extractNoCancellableResultData()

                let asset = destinationAsset.asset
                let location = destinationAsset.location

                return try Xcm.appendTransferCall(
                    asset: asset,
                    destination: location,
                    weight: maxWeight,
                    module: module,
                    codingFactory: codingFactory
                )
            }

            mapOperation.addDependency(coderFactoryOperation)

            return CompoundOperationWrapper(
                targetOperation: mapOperation,
                dependencies: [coderFactoryOperation]
            )
        case .xcmpallet:
            return createPalletXcmTransferMapping(
                dependingOn: moduleResolutionOperation,
                callPathFactory: { Xcm.limitedReserveTransferAssetsPath(for: $0) },
                destinationAssetOperation: destinationAssetOperation,
                maxWeight: maxWeight,
                runtimeProvider: runtimeProvider
            )
        case .teleport:
            return createPalletXcmTransferMapping(
                dependingOn: moduleResolutionOperation,
                callPathFactory: { Xcm.limitedTeleportAssetsPath(for: $0) },
                destinationAssetOperation: destinationAssetOperation,
                maxWeight: maxWeight,
                runtimeProvider: runtimeProvider
            )
        case .unknown:
            return .createWithError(XcmAssetTransfer.TransferTypeError.unknownType)
        }
    }

    private func createPalletXcmTransferMapping(
        dependingOn moduleResolutionOperation: BaseOperation<String>,
        callPathFactory: @escaping (String) -> CallCodingPath,
        destinationAssetOperation: BaseOperation<XcmMultilocationAsset>,
        maxWeight: BigUInt,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<(ExtrinsicBuilderClosure, CallCodingPath)> {
        let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let mapOperation = ClosureOperation<(ExtrinsicBuilderClosure, CallCodingPath)> {
            let module = try moduleResolutionOperation.extractNoCancellableResultData()
            let codingFactory = try coderFactoryOperation.extractNoCancellableResultData()
            let destinationAsset = try destinationAssetOperation.extractNoCancellableResultData()

            let (destination, beneficiary) = destinationAsset.location.separatingDestinationBenifiary()
            let assets = Xcm.VersionedMultiassets(versionedMultiasset: destinationAsset.asset)

            let callPath = callPathFactory(module)

            let argName = Xcm.PalletTransferCall.CodingKeys.weightLimit.rawValue
            let optWeight = try BlockchainWeightFactory.convertCallVersionedWeightInWeightLimitToJson(
                for: .init(path: callPath, argName: argName),
                codingFactory: codingFactory,
                weight: UInt64(maxWeight)
            )

            guard let weight = optWeight else {
                throw XcmTransferServiceError.noArgumentFound(argName)
            }

            let call = Xcm.PalletTransferCall(
                destination: destination,
                beneficiary: beneficiary,
                assets: assets,
                feeAssetItem: 0,
                weightLimit: .limited(weight: weight)
            )

            return ({ try $0.adding(call: call.runtimeCall(for: callPath)) }, callPath)
        }

        mapOperation.addDependency(coderFactoryOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [coderFactoryOperation])
    }
}
