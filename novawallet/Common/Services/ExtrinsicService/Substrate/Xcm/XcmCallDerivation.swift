import Foundation
import Operation_iOS
import SubstrateSdk

protocol XcmCallDerivating {
    func createTransferCallDerivationWrapper(
        for transferRequest: XcmUnweightedTransferRequest,
        transfers: XcmTransfersProtocol
    ) -> CompoundOperationWrapper<RuntimeCall<JSON>>
}

final class XcmCallDerivator {
    private(set) lazy var xcmFactory = XcmTransferFactory()
    private(set) lazy var xcmPalletQueryFactory = XcmPalletMetadataQueryFactory()
}

private extension XcmCallDerivator {
    func createMultilocationAssetWrapper(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfersProtocol,
        type: XcmAssetTransfer.TransferType,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<XcmMultilocationAsset> {
        switch type {
        case .xtokens:
            // we make an assumption that xtokens pallet maintains the same versions as xcm pallet
            let multiassetVersionWrapper = xcmPalletQueryFactory.createLowestMultiassetVersionWrapper(
                for: runtimeProvider
            )

            return createMultilocationAssetWrapper(
                for: multiassetVersionWrapper,
                request: request,
                xcmTransfers: xcmTransfers,
                runtimeProvider: runtimeProvider
            )
        case .xcmpallet, .teleport, .xcmpalletTransferAssets:
            let multiassetsVersionWrapper = xcmPalletQueryFactory.createLowestMultiassetsVersionWrapper(
                for: runtimeProvider
            )

            return createMultilocationAssetWrapper(
                for: multiassetsVersionWrapper,
                request: request,
                xcmTransfers: xcmTransfers,
                runtimeProvider: runtimeProvider
            )
        case .unknown:
            return .createWithError(XcmAssetTransfer.TransferTypeError.unknownType)
        }
    }

    func createMultilocationAssetWrapper(
        for multiassetVersionWrapper: CompoundOperationWrapper<Xcm.Version?>,
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfersProtocol,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<XcmMultilocationAsset> {
        let multilocationVersionWrapper = xcmPalletQueryFactory.createLowestMultilocationVersionWrapper(
            for: runtimeProvider
        )

        let transferFactory = xcmFactory

        let mappingOperation = ClosureOperation<XcmMultilocationAsset> {
            let multiassetVersion = try multiassetVersionWrapper.targetOperation.extractNoCancellableResultData()
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
        for _: XcmUnweightedTransferRequest,
        transfers _: XcmTransfersProtocol
    ) -> CompoundOperationWrapper<RuntimeCall<JSON>> {
        .createWithError(CommonError.undefined)
    }
}
