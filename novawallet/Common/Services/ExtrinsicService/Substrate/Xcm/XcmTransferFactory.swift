import Foundation
import SubstrateSdk
import BigInt

protocol XcmTransferFactoryProtocol {
    func createVersionedMultilocation(
        origin: ChainModel,
        destination: XcmTransferDestination,
        version: Xcm.Version?
    ) -> Xcm.VersionedMultilocation

    func createVersionedMultilocation(
        origin: ChainModel,
        reserve: XcmTransferReserve,
        version: Xcm.Version?
    ) -> Xcm.VersionedMultilocation

    func createVersionedMultiasset(
        origin: ChainModel,
        reserve: ChainModel,
        assetLocation: XcmAsset.ReservePath,
        amount: BigUInt,
        version: Xcm.Version?
    ) throws -> Xcm.VersionedMultiasset

    func createWeightMessages(
        from chainAsset: ChainAsset,
        reserve: XcmTransferReserve,
        destination: XcmTransferDestination,
        amount: BigUInt,
        xcmTransfers: XcmTransfers,
        version: Xcm.Version?
    ) throws -> XcmWeightMessages
}

enum XcmTransferFactoryError: Error {
    case noOriginAssetFound(ChainAssetId)
    case noDestinationAssetFound(ChainAssetId)
    case noDestinationFound(ChainModel.Id)
    case noReserve(ChainAssetId)
    case unsupportedInstruction(String)
    case noInstructions(String)
    case noDestinationFee(origin: ChainAssetId, destination: ChainModel.Id)
    case noReserveFee(ChainAssetId)
    case noBaseWeight(ChainModel.Id)
}

struct XcmMultilocationAssetParams {
    let origin: ChainAsset
    let reserve: ChainModel
    let destination: XcmTransferDestination
    let amount: BigUInt
    let xcmTransfers: XcmTransfers
}

extension XcmTransferFactoryProtocol {
    func createMultilocationAsset(
        for params: XcmMultilocationAssetParams,
        version: XcmMultilocationAssetVersion
    ) throws -> XcmMultilocationAsset {
        let chainAsset = params.origin

        let multilocation = createVersionedMultilocation(
            origin: chainAsset.chain,
            destination: params.destination,
            version: version.multiLocation
        )

        let originChainAssetId = chainAsset.chainAssetId

        guard params.xcmTransfers.transfer(
            from: originChainAssetId,
            destinationChainId: params.destination.chain.chainId
        ) != nil else {
            throw XcmTransferFactoryError.noDestinationAssetFound(originChainAssetId)
        }

        guard let reservePath = params.xcmTransfers.getReservePath(for: originChainAssetId) else {
            throw XcmTransferFactoryError.noReserve(originChainAssetId)
        }

        let multiasset = try createVersionedMultiasset(
            origin: chainAsset.chain,
            reserve: params.reserve,
            assetLocation: reservePath,
            amount: params.amount,
            version: version.multiAssets
        )

        return XcmMultilocationAsset(location: multilocation, asset: multiasset)
    }
}

final class XcmTransferFactory {}

extension XcmTransferFactory: XcmTransferFactoryProtocol {
    func createVersionedMultilocation(
        origin: ChainModel,
        destination: XcmTransferDestination,
        version: Xcm.Version?
    ) -> Xcm.VersionedMultilocation {
        switch version {
        case nil, .V0, .V1, .V2:
            XcmLegacyTransferFactory().createVersionedMultilocation(
                origin: origin,
                destination: destination,
                version: version
            )
        case .V3:
            XcmV3TransferFactory().createVersionedMultilocation(
                origin: origin,
                destination: destination,
                version: version
            )
        }
    }

    func createVersionedMultilocation(
        origin: ChainModel,
        reserve: XcmTransferReserve,
        version: Xcm.Version?
    ) -> Xcm.VersionedMultilocation {
        switch version {
        case nil, .V0, .V1, .V2:
            XcmLegacyTransferFactory().createVersionedMultilocation(
                origin: origin,
                reserve: reserve,
                version: version
            )
        case .V3:
            XcmV3TransferFactory().createVersionedMultilocation(
                origin: origin,
                reserve: reserve,
                version: version
            )
        }
    }

    func createVersionedMultiasset(
        origin: ChainModel,
        reserve: ChainModel,
        assetLocation: XcmAsset.ReservePath,
        amount: BigUInt,
        version: Xcm.Version?
    ) throws -> Xcm.VersionedMultiasset {
        switch version {
        case nil, .V0, .V1, .V2:
            try XcmLegacyTransferFactory().createVersionedMultiasset(
                origin: origin,
                reserve: reserve,
                assetLocation: assetLocation,
                amount: amount,
                version: version
            )
        case .V3:
            try XcmV3TransferFactory().createVersionedMultiasset(
                origin: origin,
                reserve: reserve,
                assetLocation: assetLocation,
                amount: amount,
                version: version
            )
        }
    }

    func createWeightMessages(
        from chainAsset: ChainAsset,
        reserve: XcmTransferReserve,
        destination: XcmTransferDestination,
        amount: BigUInt,
        xcmTransfers: XcmTransfers,
        version: Xcm.Version?
    ) throws -> XcmWeightMessages {
        switch version {
        case nil, .V0, .V1, .V2:
            try XcmLegacyTransferFactory().createWeightMessages(
                from: chainAsset,
                reserve: reserve,
                destination: destination,
                amount: amount,
                xcmTransfers: xcmTransfers,
                version: version
            )
        case .V3:
            try XcmV3TransferFactory().createWeightMessages(
                from: chainAsset,
                reserve: reserve,
                destination: destination,
                amount: amount,
                xcmTransfers: xcmTransfers,
                version: version
            )
        }
    }
}
