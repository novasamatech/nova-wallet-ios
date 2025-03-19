import Foundation

protocol XcmTransfersProtocol {
    func getChains() -> [XcmTransferChainProtocol]
}

protocol XcmTransferChainProtocol {
    var chainId: ChainModel.Id { get }
    func getAssets() -> [XcmTransferAssetProtocol]
}

protocol XcmTransferAssetProtocol {
    var assetId: AssetModel.Id { get }
    func getDestinations() -> [XcmTransferDestinationProtocol]
}

protocol XcmTransferDestinationProtocol {
    var chainId: ChainModel.Id { get }
    var assetId: AssetModel.Id { get }
    var type: XcmTransferType { get }
}
