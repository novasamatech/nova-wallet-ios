import Foundation
import SubstrateSdk
import BigInt

protocol XcmModelFactoryProtocol {
    func createVersionedMultiasset(
        origin: ChainModel,
        reserve: ChainModel,
        assetLocation: XcmAsset.ReservePath,
        amount: BigUInt,
        version: Xcm.Version?
    ) throws -> Xcm.VersionedMultiasset

    func createMultilocationAsset(
        for params: XcmMultilocationAssetParams,
        version: XcmMultilocationAssetVersion
    ) throws -> XcmMultilocationAsset
}

struct XcmMultilocationAssetParams {
    let origin: ChainAsset
    let reserve: ChainModel
    let destination: XcmTransferDestination
    let amount: BigUInt
    let xcmTransfers: XcmTransfersProtocol
}

final class XcmModelFactory {}

extension XcmModelFactory: XcmModelFactoryProtocol {
    func createVersionedMultiasset(
        origin: ChainModel,
        reserve: ChainModel,
        assetLocation: XcmAsset.ReservePath,
        amount: BigUInt,
        version: Xcm.Version?
    ) throws -> Xcm.VersionedMultiasset {
        switch version {
        case nil, .V0, .V1, .V2:
            try XcmPreV3ModelFactory().createVersionedMultiasset(
                origin: origin,
                reserve: reserve,
                assetLocation: assetLocation,
                amount: amount,
                version: version
            )
        case .V3:
            try XcmV3ModelFactory().createVersionedMultiasset(
                origin: origin,
                reserve: reserve,
                assetLocation: assetLocation,
                amount: amount,
                version: version
            )
        }
    }

    func createMultilocationAsset(
        for params: XcmMultilocationAssetParams,
        version: XcmMultilocationAssetVersion
    ) throws -> XcmMultilocationAsset {
        switch version.multiLocation {
        case nil, .V0, .V1, .V2:
            try XcmPreV3ModelFactory().createMultilocationAsset(
                for: params,
                version: version
            )
        case .V3:
            try XcmV3ModelFactory().createMultilocationAsset(
                for: params,
                version: version
            )
        }
    }
}
