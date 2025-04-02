import Foundation

enum ChainModelFetchError: Error {
    case noAsset(assetId: AssetModel.Id)
    case noAssetForSymbol(String)
}
