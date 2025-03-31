import Foundation
import SubstrateSdk
import BigInt

protocol XcmModelFactoryProtocol {
    func createMultilocationAsset(
        for params: XcmMultilocationAssetParams,
        version: Xcm.Version
    ) throws -> XcmMultilocationAsset
}

struct XcmMultilocationAssetParams {
    let origin: XcmTransferOrigin
    let reserve: XcmTransferReserve
    let destination: XcmTransferDestination
    let amount: BigUInt
    let metadata: XcmTransferMetadata
}

enum XcmModelFactoryError: Error {
    case unsupported(Xcm.Version?)
}

final class XcmModelFactory {}

private extension XcmModelFactory {
    func createDynamicMultilocationAsset(
        for params: XcmMultilocationAssetParams,
        version: Xcm.Version
    ) throws -> XcmMultilocationAsset {
        let originChainLocation = Xcm.VersionedAbsoluteLocation(
            paraId: params.origin.parachainId,
            version: version
        )

        let destinationLocation = Xcm.VersionedAbsoluteLocation(
            paraId: params.destination.parachainId,
            version: version
        )

        let assetReserveLocation = try Xcm.VersionedAbsoluteLocation.createWithRawPath(
            params.metadata.reserve.path.path,
            version: version
        )

        let benificiaryLocation = try destinationLocation.appendingAccountId(
            params.destination.accountId,
            isEthereumBase: params.destination.chain.isEthereumBased
        ).fromPointOfView(location: originChainLocation)

        let assetLocation = try assetReserveLocation.fromPointOfView(location: originChainLocation)

        let asset = Xcm.VersionedMultiasset(versionedLocation: assetLocation, amount: params.amount)

        return XcmMultilocationAsset(beneficiary: benificiaryLocation, asset: asset)
    }

    func createLegacyMultilocationAsset(
        for params: XcmMultilocationAssetParams,
        version: Xcm.Version
    ) throws -> XcmMultilocationAsset {
        switch version {
        case .V0, .V1, .V2:
            try XcmPreV3ModelFactory().createMultilocationAsset(
                for: params,
                version: version
            )
        case .V3:
            try XcmV3ModelFactory().createMultilocationAsset(
                for: params,
                version: version
            )
        case .V4:
            try XcmV4ModelFactory().createMultilocationAsset(
                for: params,
                version: version
            )
        case .V5:
            try XcmV5ModelFactory().createMultilocationAsset(
                for: params,
                version: version
            )
        }
    }
}

extension XcmModelFactory: XcmModelFactoryProtocol {
    func createMultilocationAsset(
        for params: XcmMultilocationAssetParams,
        version: Xcm.Version
    ) throws -> XcmMultilocationAsset {
        switch params.metadata.fee {
        case .dynamic:
            return try createDynamicMultilocationAsset(for: params, version: version)
        case .legacy:
            return try createLegacyMultilocationAsset(for: params, version: version)
        }
    }
}
