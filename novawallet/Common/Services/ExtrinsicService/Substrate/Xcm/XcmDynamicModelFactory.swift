import Foundation

final class XcmDynamicModelFactory {}

extension XcmDynamicModelFactory: XcmModelFactoryProtocol {
    func createMultilocationAsset(
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
