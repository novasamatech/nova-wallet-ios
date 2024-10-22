import Foundation
import BigInt
import Operation_iOS

extension ListDifferenceCalculator where T == AssetListChainGroupModel {
    static let empty: ListDifferenceCalculator<T> = AssetListModelHelpers.createGroupsDiffCalculator(
        from: [],
        defaultComparingBy: \.chain
    )
}

extension ListDifferenceCalculator where T == AssetListAssetGroupModel {
    static let empty: ListDifferenceCalculator<T> = AssetListModelHelpers.createAssetGroupsDiffCalculator(from: [])
}

extension ListDifferenceCalculator where T == AssetListAssetModel {
    static let empty: ListDifferenceCalculator<T> = AssetListModelHelpers.createAssetsDiffCalculator(
        from: []
    )
}

struct AssetListBuilderResult {
    struct Model {
        let chainGroups: [AssetListChainGroupModel]
        let assetGroups: [AssetListAssetGroupModel]
        let groupListsByChain: [ChainModel.Id: [AssetListAssetModel]]
        let groupListsByAsset: [AssetModel.Symbol: [AssetListAssetModel]]
        let priceResult: Result<[ChainAssetId: PriceData], Error>?
        let balanceResults: [ChainAssetId: Result<BigUInt, Error>]
        let allChains: [ChainModel.Id: ChainModel]
        let balances: [ChainAssetId: Result<AssetBalance, Error>]
        let externalBalanceResult: Result<[ChainAssetId: [ExternalAssetBalance]], Error>?
        let nfts: [NftModel]
        let locksResult: Result<[AssetLock], Error>?
        let holdsResult: Result<[AssetHold], Error>?

        init(
            chainGroups: [AssetListChainGroupModel] = [],
            assetGroups: [AssetListAssetGroupModel] = [],
            groupListsByChain: [ChainModel.Id: [AssetListAssetModel]] = [:],
            groupListsByAsset: [AssetModel.Symbol: [AssetListAssetModel]] = [:],
            priceResult: Result<[ChainAssetId: PriceData], Error>? = nil,
            balanceResults: [ChainAssetId: Result<BigUInt, Error>] = [:],
            allChains: [ChainModel.Id: ChainModel] = [:],
            balances: [ChainAssetId: Result<AssetBalance, Error>] = [:],
            externalBalanceResult: Result<[ChainAssetId: [ExternalAssetBalance]], Error>? = nil,
            nfts: [NftModel] = [],
            locksResult: Result<[AssetLock], Error>? = nil,
            holdsResult: Result<[AssetHold], Error>? = nil
        ) {
            self.chainGroups = chainGroups
            self.assetGroups = assetGroups
            self.groupListsByChain = groupListsByChain
            self.groupListsByAsset = groupListsByAsset
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
                chainGroups: chainGroups,
                assetGroups: assetGroups,
                groupListsByChain: groupListsByChain,
                groupListsByAsset: groupListsByAsset,
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
