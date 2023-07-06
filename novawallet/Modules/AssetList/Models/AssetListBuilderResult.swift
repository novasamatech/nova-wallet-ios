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
        let crowdloansResult: Result<[ChainModel.Id: [CrowdloanContributionData]], Error>?
        let nfts: [NftModel]
        let locksResult: Result<[AssetLock], Error>?

        init(
            groups: [AssetListGroupModel] = [],
            groupLists: [ChainModel.Id: [AssetListAssetModel]] = [:],
            priceResult: Result<[ChainAssetId: PriceData], Error>? = nil,
            balanceResults: [ChainAssetId: Result<BigUInt, Error>] = [:],
            allChains: [ChainModel.Id: ChainModel] = [:],
            balances: [ChainAssetId: Result<AssetBalance, Error>] = [:],
            crowdloansResult: Result<[ChainModel.Id: [CrowdloanContributionData]], Error>? = nil,
            nfts: [NftModel] = [],
            locksResult: Result<[AssetLock], Error>? = nil
        ) {
            self.groups = groups
            self.groupLists = groupLists
            self.priceResult = priceResult
            self.balanceResults = balanceResults
            self.allChains = allChains
            self.balances = balances
            self.crowdloansResult = crowdloansResult
            self.nfts = nfts
            self.locksResult = locksResult
        }

        func replacing(nfts: [NftModel]) -> Model {
            .init(
                groups: groups,
                groupLists: groupLists,
                priceResult: priceResult,
                balanceResults: balanceResults,
                allChains: allChains,
                balances: balances,
                crowdloansResult: crowdloansResult,
                nfts: nfts,
                locksResult: locksResult
            )
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
