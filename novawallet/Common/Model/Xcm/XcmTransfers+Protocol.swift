import Foundation

extension XcmLegacyTransfers: XcmTransfersProtocol {
    func getChains() -> [XcmTransferChainProtocol] {
        chains
    }
}

extension XcmChain: XcmTransferChainProtocol {
    func getAssets() -> [XcmTransferAssetProtocol] {
        assets
    }
}

extension XcmAsset: XcmTransferAssetProtocol {
    func getDestinations() -> [XcmTransferDestinationProtocol] {
        xcmTransfers
    }
}

extension XcmAssetTransfer: XcmTransferDestinationProtocol {
    var chainId: ChainModel.Id {
        destination.chainId
    }

    var assetId: AssetModel.Id {
        destination.assetId
    }
}
