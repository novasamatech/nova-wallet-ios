import Foundation

protocol RaiseTokensConverting {
    func convertToChainAsset(from token: RaiseCryptoAssetRemote) -> ChainAssetId?
    func convertToCrytoAsset(from chainAssetId: ChainAssetId) -> RaiseCryptoAssetLocal?
}

final class RaiseTokensConverter {
    let cryptoAssetsMapping: [String: [String: ChainAssetId]] = [
        "POLKADOT": ["DOT": ChainAssetId(
            chainId: KnowChainId.polkadot,
            assetId: AssetModel.utilityAssetId
        )],
        "POLKADOT_TESTNET": ["WND": ChainAssetId(
            chainId: KnowChainId.westend,
            assetId: AssetModel.utilityAssetId
        )]
    ]
}

extension RaiseTokensConverter: RaiseTokensConverting {
    func convertToChainAsset(
        from token: RaiseCryptoAssetRemote
    ) -> ChainAssetId? {
        let knownNetwork = cryptoAssetsMapping[token.attributes.network]

        return knownNetwork?[token.attributes.name]
    }

    func convertToCrytoAsset(from chainAssetId: ChainAssetId) -> RaiseCryptoAssetLocal? {
        let allNetworks = cryptoAssetsMapping.keys

        for network in allNetworks {
            if let symbols = cryptoAssetsMapping[network]?.keys {
                for symbol in symbols {
                    if
                        let targetAssetId = cryptoAssetsMapping[network]?[symbol],
                        chainAssetId == targetAssetId {
                        return RaiseCryptoAssetLocal(symbol: symbol, network: network)
                    }
                }
            }
        }

        return nil
    }
}
