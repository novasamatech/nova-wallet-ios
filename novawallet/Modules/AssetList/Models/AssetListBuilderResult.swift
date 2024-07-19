import Foundation
import BigInt

struct AssetListBuilderResult {
    struct Model {
        let groups: [AssetListGroupModel]
        let groupLists: [ChainModel.Id: [AssetListAssetModel]]
        let priceResult: Result<[ChainAssetId: PriceData], Error>?
        let balanceResults: [ChainAssetId: Result<BigUInt, Error>]
        let allChains: [ChainModel.Id: ChainModel]
        let balances: [ChainAssetId: Result<AssetBalance, Error>]
        let externalBalanceResult: Result<[ChainAssetId: [ExternalAssetBalance]], Error>?
        let nfts: [NftModel]
        let locksResult: Result<[AssetLock], Error>?
        let holdsResult: Result<[AssetHold], Error>?

        init(
            groups: [AssetListGroupModel] = [],
            groupLists: [ChainModel.Id: [AssetListAssetModel]] = [:],
            priceResult: Result<[ChainAssetId: PriceData], Error>? = nil,
            balanceResults: [ChainAssetId: Result<BigUInt, Error>] = [:],
            allChains: [ChainModel.Id: ChainModel] = [:],
            balances: [ChainAssetId: Result<AssetBalance, Error>] = [:],
            externalBalanceResult: Result<[ChainAssetId: [ExternalAssetBalance]], Error>? = nil,
            nfts: [NftModel] = [],
            locksResult: Result<[AssetLock], Error>? = nil,
            holdsResult: Result<[AssetHold], Error>? = nil
        ) {
            self.groups = groups
            self.groupLists = groupLists
            self.priceResult = priceResult
            self.balanceResults = balanceResults
            self.allChains = allChains
            self.balances = balances
            self.externalBalanceResult = externalBalanceResult
            self.nfts = nfts
            self.locksResult = locksResult
            self.holdsResult = holdsResult
        }

        func replacing(nfts: [NftModel]) -> Model {
            .init(
                groups: groups,
                groupLists: groupLists,
                priceResult: priceResult,
                balanceResults: balanceResults,
                allChains: allChains,
                balances: balances,
                externalBalanceResult: externalBalanceResult,
                nfts: nfts,
                locksResult: locksResult
            )
        }

        func hasSwaps() -> Bool {
            allChains.values.contains { chain in
                guard chain.hasSwaps else {
                    return false
                }
                return chain.assets.contains { asset in
                    let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)
                    if case .success = balanceResults[chainAssetId] {
                        return true
                    } else {
                        return false
                    }
                }
            }
        }
    }

    enum ChangeKind {
        case reload
        case nfts
    }

    let walletId: MetaAccountModel.Id?
    let model: Model
    let changeKind: ChangeKind
}
