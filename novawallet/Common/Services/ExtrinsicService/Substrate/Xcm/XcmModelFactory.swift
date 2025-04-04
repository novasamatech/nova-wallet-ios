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
    func createLegacyMultilocationAsset(
        for params: XcmMultilocationAssetParams,
        version: Xcm.Version
    ) throws -> XcmMultilocationAsset {
        try XcmPreV3ModelFactory().createMultilocationAsset(
            for: params,
            version: version
        )
    }
}

private extension XcmModelFactory {
    func createDynamicMultilocationAsset(
        for params: XcmMultilocationAssetParams,
        version: Xcm.Version
    ) throws -> XcmMultilocationAsset {
        let originChainLocation = XcmUni.AbsoluteLocation(paraId: params.origin.parachainId)

        let destinationLocation = XcmUni.AbsoluteLocation(paraId: params.destination.parachainId)

        let assetReserveLocation = try XcmUni.AbsoluteLocation.createWithRawPath(params.metadata.reserve.path.path)

        let benificiaryLocation = destinationLocation.appendingAccountId(
            params.destination.accountId,
            isEthereumBase: params.destination.chain.isEthereumBased
        ).fromPointOfView(location: originChainLocation)

        let assetLocation = assetReserveLocation.fromPointOfView(location: originChainLocation)

        let asset = XcmUni.Asset(location: assetLocation, amount: params.amount)

        return XcmMultilocationAsset(
            beneficiary: benificiaryLocation.versioned(version),
            asset: asset.versioned(version)
        )
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
