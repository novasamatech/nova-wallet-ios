import Foundation

enum ChainRegistryError: Error {
    case connectionUnavailable
    case runtimeMetadaUnavailable
    case noChain(ChainModel.Id)
    case noChainAsset(ChainAssetId)
    case noUtilityAsset(ChainModel.Id)
}
