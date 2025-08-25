import Foundation

enum Caip19 {}

extension Caip19 {
    struct AssetId: Hashable {
        let chainId: Caip2.ChainId
        let assetNamespace: String
        let assetReference: String
        let tokenId: String?

        init(raw: String) throws {
            let chainAsset = raw.split(by: .slash)
            chainId = try .init(raw: chainAsset[0])

            let asset = chainAsset[1].split(by: .colon)
            guard asset.count == 2 else {
                throw ParseError.invalidAssetString
            }
            let parsedAssetNamespace = asset[0]
            let parsedAssetReference = asset[1]

            if let namespaceCheckError = parsedAssetNamespace.checkLength(min: 3, max: 8) {
                throw ParseError.invalidAssetNamespace(namespaceCheckError)
            }
            if let referenceCheckError = parsedAssetReference.checkLength(min: 1, max: 128) {
                throw ParseError.invalidAssetReference(referenceCheckError)
            }

            assetNamespace = parsedAssetNamespace
            assetReference = parsedAssetReference

            tokenId = chainAsset[safe: 2]
        }
    }
}

extension Caip19 {
    typealias Slip44CoinIndex = Int

    enum RegisteredToken: Equatable {
        case slip44(coin: Slip44CoinIndex)
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

        static func createFromAsset(_ asset: AssetModel, slip44Store: Slip44CoinList) -> RegisteredToken? {
            let assetType = asset.type.flatMap { AssetType(rawValue: $0) }

            switch assetType {
            case .evmAsset:
                if let evmContract = asset.evmContractAddress {
                    return .erc20(contract: evmContract)
                } else {
                    return nil
                }
            case .none, .statemine, .orml, .ormlHydrationEvm, .evmNative, .equilibrium:
                if
                    let slip44 = slip44Store.matchFirstCaip19(
                        of: MultichainToken.reserveTokensOf(symbol: asset.symbol)
                    ) {
                    return slip44
                } else {
                    return nil
                }
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

    var slip44Code: Int? {
        guard case let .slip44(coin) = knownToken else {
            return nil
        }
        return coin
    }

    func match(chain: ChainModel, token: Caip19.RegisteredToken) -> Bool {
        guard chainId.match(chain) else {
            return false
        }

        return token == knownToken
    }
}
