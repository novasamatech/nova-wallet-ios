import Foundation

enum SwapTokenSelectListBuilder {
    static func build(from params: SwapTokenSelectListParams) -> SwapTokenSelectList? {
        guard let universe = createUniverse(from: params) else {
            return nil
        }

        let filteredAssets = search(
            in: filter(universe, by: params.networkFilter),
            query: params.query
        )

        let rank = params.assetList.visibility?.defaults.rank ?? [:]

        let items = filteredAssets
            .map { createItem(for: $0, assetList: params.assetList) }
            .sorted { compare($0, $1, rank: rank) }

        var yourTokens: [SwapTokenSelectItem] = []
        var otherTokens: [SwapTokenSelectItem] = []
        var notSwappable: [SwapTokenSelectItem] = []

        let swappable = params.context.counterpart != nil ? params.swappable : nil

        for item in items {
            if let swappable, !swappable.contains(item.chainAsset.chainAssetId) {
                notSwappable.append(item)
            } else if item.hasBalance {
                yourTokens.append(item)
            } else {
                otherTokens.append(item)
            }
        }

        return SwapTokenSelectList(
            yourTokens: yourTokens,
            otherTokens: otherTokens,
            notSwappable: notSwappable,
            balancesLoading: hasPendingBalances(in: filteredAssets, assetList: params.assetList),
            networks: extractNetworks(from: universe)
        )
    }

    static func relayChainIds(in chains: [ChainModel]) -> Set<ChainModel.Id> {
        Set(chains.compactMap(\.parentId)).union([KnowChainId.polkadot, KnowChainId.kusama])
    }
}

// MARK: Private

private extension SwapTokenSelectListBuilder {
    static func createUniverse(from params: SwapTokenSelectListParams) -> [ChainAsset]? {
        let assetList = params.assetList
        let relayIds = relayChainIds(in: Array(assetList.chainsIncludingHidden.values))
        let counterpartId = params.context.counterpart?.chainAssetId

        let chainAssets = assetList.chains(includingHidden: params.side == .receive)
            .values
            .filter { !relayIds.contains($0.chainId) }
            .flatMap { chain in chain.assets.map { ChainAsset(chain: chain, asset: $0) } }
            .filter { $0.chainAssetId != counterpartId }

        switch params.side {
        case .pay:
            guard let routeUniverse = params.routeUniverse else {
                return nil
            }

            return chainAssets.filter { routeUniverse.contains($0.chainAssetId) }
        case .receive:
            return chainAssets
        }
    }

    static func filter(_ chainAssets: [ChainAsset], by networkIds: Set<ChainModel.Id>) -> [ChainAsset] {
        guard !networkIds.isEmpty else {
            return chainAssets
        }

        return chainAssets.filter { networkIds.contains($0.chain.chainId) }
    }

    static func search(in chainAssets: [ChainAsset], query: String) -> [ChainAsset] {
        guard !query.isEmpty else {
            return chainAssets
        }

        let symbolMatches = chainAssets.compactMap { chainAsset in
            SearchMatch<ChainAsset>.matchString(
                for: query,
                recordField: chainAsset.asset.symbol,
                record: chainAsset
            )
        }

        let symbolMatchedAssets = symbolMatches.map(\.item)

        if symbolMatches.contains(where: \.isFull) {
            return symbolMatchedAssets
        }

        let matchedIds = Set(symbolMatchedAssets.map(\.chainAssetId))

        let networkMatchedAssets = chainAssets.filter { chainAsset in
            guard !matchedIds.contains(chainAsset.chainAssetId) else {
                return false
            }

            return SearchMatch.matchInclusion(
                for: query,
                recordField: chainAsset.chain.name,
                record: chainAsset.chain
            ) != nil
        }

        return symbolMatchedAssets + networkMatchedAssets
    }

    static func createItem(for chainAsset: ChainAsset, assetList: AssetListModel) -> SwapTokenSelectItem {
        let chainAssetId = chainAsset.chainAssetId
        let precision = chainAsset.assetDisplayInfo.assetPrecision

        let balance = (try? assetList.balances[chainAssetId]?.get()).flatMap {
            Decimal.fromSubstrateAmount($0.transferable, precision: precision)
        }

        let priceData = try? assetList.priceResult?.get()[chainAssetId]

        let value: Decimal? = if let balance, let price = priceData.flatMap({ Decimal(string: $0.price) }) {
            balance * price
        } else {
            nil
        }

        return SwapTokenSelectItem(
            chainAsset: chainAsset,
            balance: balance,
            value: value,
            priceData: priceData
        )
    }

    static func compare(
        _ lhs: SwapTokenSelectItem,
        _ rhs: SwapTokenSelectItem,
        rank: [ChainAssetId: Int]
    ) -> Bool {
        let lhsValue = lhs.value ?? 0
        let rhsValue = rhs.value ?? 0

        if lhsValue != rhsValue {
            return lhsValue > rhsValue
        }

        let lhsBalance = lhs.balance ?? 0
        let rhsBalance = rhs.balance ?? 0

        if lhsBalance != rhsBalance {
            return lhsBalance > rhsBalance
        }

        switch (rank[lhs.chainAsset.chainAssetId], rank[rhs.chainAsset.chainAssetId]) {
        case let (lhsRank?, rhsRank?) where lhsRank != rhsRank:
            return lhsRank < rhsRank
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            break
        }

        let lhsChain = lhs.chainAsset.chain
        let rhsChain = rhs.chainAsset.chain

        if lhsChain.chainId != rhsChain.chainId {
            return ChainModelCompator.defaultComparator(chain1: lhsChain, chain2: rhsChain)
        }

        return lhs.chainAsset.asset.symbol.lexicographicallyPrecedes(rhs.chainAsset.asset.symbol)
    }

    static func hasPendingBalances(in chainAssets: [ChainAsset], assetList: AssetListModel) -> Bool {
        chainAssets.contains { chainAsset in
            let chainAssetId = chainAsset.chainAssetId

            guard assetList.allChains[chainAssetId.chainId]?.asset(for: chainAssetId.assetId) != nil else {
                return false
            }

            return assetList.balanceResults[chainAssetId] == nil
        }
    }

    static func extractNetworks(from chainAssets: [ChainAsset]) -> [ChainModel] {
        let chains = chainAssets.reduce(into: [ChainModel.Id: ChainModel]()) { result, chainAsset in
            result[chainAsset.chain.chainId] = chainAsset.chain
        }

        return Array(chains.values).sortedUsingDefaultComparator()
    }
}
