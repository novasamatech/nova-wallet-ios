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
        var result = [ChainModel.Id: Set<AssetModel>]()

        for token in self {
            for instance in token.instances {
                guard let asset = AssetModel(evmToken: token, evmInstance: instance) else {
                    continue
                }
                var assets = result[instance.chainId] ?? Set<AssetModel>()
                assets.insert(asset)
                result[instance.chainId] = assets
            }
        }

        return result
    }
}
