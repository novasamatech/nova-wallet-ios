import Foundation
import SubstrateSdk

extension RemoteAssetModel {
    init?(evmToken: RemoteEvmToken, evmInstance: RemoteEvmToken.Instance) {
        guard let assetId = AssetModel.createAssetId(from: evmInstance.contractAddress) else {
            return nil
        }

        self.init(
            assetId: assetId,
            icon: evmToken.icon,
            name: evmToken.name,
            symbol: evmToken.symbol,
            precision: UInt16(evmToken.precision),
            priceId: evmToken.priceId,
            staking: nil,
            type: AssetType.evmAsset.rawValue,
            typeExtras: AssetTypeExtras.createFrom(evmContractAddress: evmInstance.contractAddress),
            buyProviders: evmInstance.buyProviders,
            sellProviders: evmInstance.sellProviders
        )
    }
}

extension Array where Element == RemoteEvmToken {
    func chainAssets() -> [ChainModel.Id: [RemoteAssetModel]] {
        let chainAssets = flatMap { token in
            token.instances.compactMap { instance -> (chainId: ChainModel.Id, asset: RemoteAssetModel)? in
                guard let asset = RemoteAssetModel(evmToken: token, evmInstance: instance) else {
                    return nil
                }
                return (chainId: instance.chainId, asset: asset)
            }
        }

        return chainAssets.reduce(into: [ChainModel.Id: [RemoteAssetModel]]()) { result, chainAsset in
            var assets = result[chainAsset.chainId] ?? []
            assets.append(chainAsset.asset)
            result[chainAsset.chainId] = assets
        }
    }
}
