import Foundation
import Operation_iOS
import BigInt

class AssetSearchBuilder: AnyCancellableCleaning {
    let workingQueue: DispatchQueue
    let callbackQueue: DispatchQueue
    let operationQueue: OperationQueue
    let callbackClosure: (AssetSearchBuilderResult) -> Void
    let filter: ChainAssetsFilter?
    let logger: LoggerProtocol

    private var state: AssetListState?

    private var query: String = ""

    private let callStore = CancellableCallStore()

    init(
        filter: ChainAssetsFilter?,
        workingQueue: DispatchQueue,
        callbackQueue: DispatchQueue,
        callbackClosure: @escaping (AssetSearchBuilderResult) -> Void,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.filter = filter
        self.workingQueue = workingQueue
        self.callbackQueue = callbackQueue
        self.callbackClosure = callbackClosure
        self.operationQueue = operationQueue
        self.logger = logger
    }

    func assetListState(from model: AssetListModel) -> AssetListState {
        let chainAssets = model.allChains.flatMap { _, chain in
            chain.assets.map { ChainAssetId(chainId: chain.chainId, assetId: $0.assetId) }
        }

        let balanceResults = chainAssets.reduce(into: [ChainAssetId: Result<BigUInt, Error>]()) {
            switch model.balances[$1] {
            case let .success(amount):
                $0[$1] = .success(amount.totalInPlank)
            case let .failure(error):
                $0[$1] = .failure(error)
            case .none:
                $0[$1] = .success(0)
            }
        }

        return AssetListState(
            priceResult: model.priceResult,
            balanceResults: balanceResults,
            allChains: model.allChains,
            externalBalances: model.externalBalances
        )
    }

    func createFilterWrapper(
        for query: String,
        filter: ChainAssetsFilter?,
        chains: [ChainModel.Id: ChainModel]
    ) -> CompoundOperationWrapper<[ChainAsset]> {
        let chainAssets = filterAssets(
            for: query,
            filter: filter,
            chains: chains
        )

        return .createWithResult(chainAssets)
    }
}

private extension AssetSearchBuilder {
    func createSearchWrapper(
        for query: String,
        filter: ChainAssetsFilter?,
        state: AssetListState
    ) -> CompoundOperationWrapper<AssetSearchBuilderResult> {
        let filterWrapper = createFilterWrapper(
            for: query,
            filter: filter,
            chains: state.allChains
        )

        let resultOperation = ClosureOperation<AssetSearchBuilderResult> {
            let chainAssets = try filterWrapper.targetOperation.extractNoCancellableResultData()

            return self.createResult(from: chainAssets, state: state)
        }

        resultOperation.addDependency(filterWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: filterWrapper.allOperations
        )
    }

    func rebuildResult(for query: String, filter: ChainAssetsFilter?) {
        guard let state = state else {
            return
        }

        let searchWrapper = createSearchWrapper(
            for: query,
            filter: filter,
            state: state
        )

        executeCancellable(
            wrapper: searchWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: workingQueue
        ) { [weak self] result in
            switch result {
            case let .success(builderResult):
                self?.callbackQueue.async {
                    self?.callbackClosure(builderResult)
                }
            case let .failure(error):
                self?.logger.error("Unexpected error: \(error)")
            }
        }
    }

    func createResult(
        from assets: [ChainAsset],
        state: AssetListState
    ) -> AssetSearchBuilderResult {
        let assetModels = assets.reduce(into: [ChainModel.Id: [AssetListAssetModel]]()) { result, chainAsset in
            let assetModel = AssetListModelHelpers.createAssetModel(
                for: chainAsset.chain,
                assetModel: chainAsset.asset,
                state: state
            )

            let currentModels = result[chainAsset.chain.chainId] ?? []
            result[chainAsset.chain.chainId] = currentModels + [assetModel]
        }

        let groupListsByChain = assetModels.mapValues { models in
            let comparator = AssetListModelHelpers.assetSortByUtilityThenPriority

            return models.sorted(by: comparator)
        }

        let chainGroups: [AssetListChainGroupModel] = assetModels.compactMap { chainId, assetModels in
            guard let chain = state.allChains[chainId] else {
                return nil
            }

            return AssetListModelHelpers.createChainGroupModel(
                from: chain,
                assets: assetModels
            )
        }

        let comparator = AssetListModelHelpers.assetListChainGroupSortingBlock
        let sortedChainGroups = chainGroups.sorted(by: comparator)

        let (assetGroups, groupListsByAsset) = buildAssetGroups(
            from: assets,
            using: state
        )

        return AssetSearchBuilderResult(
            chainGroups: sortedChainGroups,
            assetGroups: assetGroups,
            groupListsByChain: groupListsByChain,
            groupListsByAsset: groupListsByAsset,
            state: state
        )
    }

    func buildAssetGroups(
        from assets: [ChainAsset],
        using state: AssetListState
    ) -> (
        groups: [AssetListAssetGroupModel],
        groupsList: [AssetModel.Symbol: [AssetListAssetModel]]
    ) {
        var newGroups: [AssetListAssetGroupModel] = []
        var newGroupListsByAsset: [AssetModel.Symbol: [AssetListAssetModel]] = [:]

        var tokensBySymbol: [AssetModel.Symbol: MultichainToken] = [:]
        var tokensByChainAsset: [ChainAssetId: MultichainToken] = [:]

        assets
            .createMultichainTokens()
            .forEach { token in
                token.instances.forEach {
                    tokensByChainAsset[$0.chainAssetId] = token
                }

                tokensBySymbol[token.symbol] = token
            }

        assetsBySymbol(
            using: tokensByChainAsset,
            state: state
        )
        .forEach { symbol, assetListModels in
            let comparator = AssetListModelHelpers.chainAssetSortByUtilityThenPriority
            let sortedModels = assetListModels.sorted(by: comparator)

            newGroupListsByAsset[symbol] = sortedModels

            guard let token = tokensBySymbol[symbol] else {
                return
            }

            let groupModel = AssetListModelHelpers.createAssetGroupModel(
                token: token,
                assets: assetListModels
            )

            newGroups.append(groupModel)
        }

        let groupsComparator = AssetListModelHelpers.assetListAssetGroupSortingBlock
        newGroups.sort(by: groupsComparator)

        return (newGroups, newGroupListsByAsset)
    }

    func assetsBySymbol(
        using tokensByChainAsset: [ChainAssetId: MultichainToken],
        state: AssetListState
    ) -> [AssetModel.Symbol: [AssetListAssetModel]] {
        tokensByChainAsset.reduce(into: [AssetModel.Symbol: [AssetListAssetModel]]()) { acc, keyValue in
            let models: [AssetListAssetModel] = keyValue.value.instances.compactMap { instance in
                guard
                    let chain = state.allChains[instance.chainAssetId.chainId],
                    let asset = chain.asset(for: instance.chainAssetId.assetId)
                else {
                    return nil
                }

                return AssetListModelHelpers.createAssetModel(
                    for: chain,
                    assetModel: asset,
                    state: state
                )
            }

            acc[keyValue.value.symbol] = models
        }
    }

    func filterAssets(
        for query: String,
        filter: ChainAssetsFilter?,
        chains: [ChainModel.Id: ChainModel]
    ) -> [ChainAsset] {
        var chainAssets = chains.values.flatMap { chain in
            chain.assets.map { ChainAsset(chain: chain, asset: $0) }
        }

        if let filter = filter {
            chainAssets = chainAssets.filter(filter)
        }

        guard !query.isEmpty else {
            return chainAssets
        }

        let allAssetsMatching = chainAssets.compactMap { chainAsset in
            SearchMatch<ChainAsset>.matchString(for: query, recordField: chainAsset.asset.symbol, record: chainAsset)
        }

        let allMatchedAssets = allAssetsMatching.map(\.item)

        if allAssetsMatching.contains(where: { $0.isFull }) {
            return allMatchedAssets
        }

        let matchedChainAssetsIds = Set(allMatchedAssets.map(\.chainAssetId))

        var allMatchedChains = chains.values.reduce(into: [ChainAsset]()) { result, chain in
            let match = SearchMatch.matchInclusion(
                for: query,
                recordField: chain.name,
                record: chain
            )

            guard match != nil else {
                return
            }

            chain.assets.forEach { asset in
                let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)

                if !matchedChainAssetsIds.contains(chainAssetId) {
                    let chainAsset = ChainAsset(chain: chain, asset: asset)
                    result.append(chainAsset)
                }
            }
        }

        if let filter = filter {
            allMatchedChains = allMatchedChains.filter(filter)
        }

        return allMatchedAssets + allMatchedChains
    }
}

extension AssetSearchBuilder {
    func apply(query: String) {
        workingQueue.async { [weak self] in
            guard let self = self else {
                return
            }

            self.query = query
            self.rebuildResult(for: self.query, filter: self.filter)
        }
    }

    func apply(model: AssetListModel) {
        workingQueue.async { [weak self] in
            guard let self = self else {
                return
            }

            self.state = self.assetListState(from: model)
            self.rebuildResult(for: self.query, filter: self.filter)
        }
    }

    func reload() {
        workingQueue.async { [weak self] in
            guard let self = self else {
                return
            }

            self.rebuildResult(for: self.query, filter: self.filter)
        }
    }
}
