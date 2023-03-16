import Foundation

enum Caip19 {}

extension Caip19 {
    struct AssetId {
        let chainId: Caip2.ChainId
        let assetNamespace: String
        let assetReference: String
        let tokenId: String?

        init?(raw: String) {
            let chainAsset = raw.split(by: .slash)
            guard chainAsset.count >= 2 else {
                return nil
            }

            let chain = chainAsset[0].split(by: .colon)
            guard chain.count == 2 else {
                return nil
            }
            chainId = .init(
                namespace: chain[0],
                reference: chain[1]
            )

            let asset = chainAsset[1].split(by: .colon)
            guard asset.count == 2 else {
                return nil
            }
            assetNamespace = asset[0]
            assetReference = asset[1]

            tokenId = chainAsset[safe: 2]
        }
    }
}

extension Caip19 {
    enum RegisteredToken: Equatable {
        case slip44(coin: Int)
        case erc20(contract: String)
        case erc721(contract: String)

        static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case let (.slip44(coin), .slip44(otherCoin)):
                return coin == otherCoin
            case let (.erc20(contract), .erc20(otherContract)):
                return contract == otherContract
            case let (.erc721(contract), .erc721(otherContract)):
                return contract == otherContract
            default:
                return false
            }
        }
    }
}

extension Caip19.AssetId {
    var knownToken: Caip19.RegisteredToken? {
        switch assetNamespace {
        case "slip44":
            guard let coin = Int(assetReference) else {
                return nil
            }
            return .slip44(coin: coin)
        case "erc20":
            return .erc20(contract: assetReference)
        case "erc721":
            return .erc721(contract: assetReference)
        default:
            return nil
        }
    }
}
