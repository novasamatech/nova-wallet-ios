import Foundation

extension XcmDynamicTransfers: XcmTransfersProtocol {
    func getChains() -> [XcmTransferChainProtocol] {
        chains
    }
}

extension XcmDynamicChain: XcmTransferChainProtocol {
    func getAssets() -> [XcmTransferAssetProtocol] {
        assets
    }
}

extension XcmDynamicAsset: XcmTransferAssetProtocol {
    func getDestinations() -> [XcmTransferDestinationProtocol] {
        xcmTransfers
    }
}

extension XcmDynamicAssetTransfer: XcmTransferDestinationProtocol {
    var type: XcmTransferType { .xcmpalletTransferAssets }
}
