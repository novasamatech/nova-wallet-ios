import Foundation
import SubstrateSdk
import xxHash_Swift

extension AssetModel {
    init?(evmToken: RemoteEvmToken, evmInstance: RemoteEvmToken.Instance) {
        guard let ethereumAccountId = try? evmInstance.contractAddress.toEthereumAccountId() else {
            return nil
        }
        let assetId = XXH32.digest(ethereumAccountId)
        let iconURL: URL?

        if let icon = evmToken.icon {
            iconURL = URL(string: icon)
        } else {
            iconURL = nil
        }

        self.init(
            assetId: assetId,
            icon: iconURL,
            name: evmToken.name,
            symbol: evmToken.symbol,
            precision: UInt16(evmToken.precision),
            priceId: evmToken.priceId,
            staking: nil,
            type: "evm",
            typeExtras: JSON.stringValue(evmInstance.contractAddress),
            buyProviders: nil
        )
    }
}

extension Array where Element == RemoteEvmToken {
    func chainAssets() -> [ChainModel.Id: Set<AssetModel>] {
        let chainAssets = flatMap { token in
            token.instances.compactMap { instance -> (chainId: ChainModel.Id, asset: AssetModel)? in
                guard let asset = AssetModel(evmToken: token, evmInstance: instance) else {
                    return nil
                }
                return (chainId: instance.chainId, asset: asset)
            }
        }

        return chainAssets.reduce(into: [ChainModel.Id: Set<AssetModel>]()) { result, chainAsset in
            var assets = result[chainAsset.chainId] ?? Set<AssetModel>()
            assets.insert(chainAsset.asset)
            result[chainAsset.chainId] = assets
        }
    }
}
