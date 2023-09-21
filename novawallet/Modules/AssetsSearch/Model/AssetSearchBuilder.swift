import Foundation
import RobinHood
import BigInt

class AssetSearchBuilder: AnyCancellableCleaning {
    let workingQueue: DispatchQueue
    let callbackQueue: DispatchQueue
    let operationQueue: OperationQueue
    let callbackClosure: (AssetSearchBuilderResult) -> Void
    let filter: ChainAssetsFilter?
    let logger: LoggerProtocol

    private var model: AssetListModel
    private var state: AssetListState?

    private var query: String = ""
    private var currentOperation: CancellableCall?

    init(
        filter: ChainAssetsFilter?,
        model: AssetListModel,
        workingQueue: DispatchQueue,
        callbackQueue: DispatchQueue,
        callbackClosure: @escaping (AssetSearchBuilderResult) -> Void,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.filter = filter
        self.model = model
        self.workingQueue = workingQueue
        self.callbackQueue = callbackQueue
        self.callbackClosure = callbackClosure
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func rebuildResult(for query: String, filter: ChainAssetsFilter?) {
        rebuildResult(for: query, state: state ?? assetState(from: model), filter: filter)
    }

    private func rebuildResult(for query: String, state: AssetListState, filter: ChainAssetsFilter?) {
        clear(cancellable: &currentOperation)

        let searchOperation = ClosureOperation<AssetSearchBuilderResult> {
            let chainAssets = self.filterAssets(
                for: query,
                filter: filter,
                chains: state.allChains
            )

            return self.createResult(from: chainAssets, state: state)
        }

        searchOperation.completionBlock = { [weak self] in
            self?.workingQueue.async {
                guard searchOperation === self?.currentOperation else {
                    return
                }

                self?.currentOperation = nil

                do {
                    let result = try searchOperation.extractNoCancellableResultData()

                    self?.callbackQueue.async {
                        self?.callbackClosure(result)
                    }
                } catch {
                    self?.logger.error("Unexpected error: \(error)")
                }
            }
        }

        currentOperation = searchOperation

        operationQueue.addOperation(searchOperation)
    }

    private func createResult(
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

        let groupAssetCalculators = assetModels.mapValues { models in
            AssetListModelHelpers.createAssetsDiffCalculator(from: models)
        }

        let chainModels: [AssetListGroupModel] = assetModels.compactMap { chainId, assetModels in
            guard let chain = state.allChains[chainId] else {
                return nil
            }

            return AssetListModelHelpers.createGroupModel(from: chain, assets: assetModels)
        }

        let groupChainCalculator = AssetListModelHelpers.createGroupsDiffCalculator(from: chainModels)

        return AssetSearchBuilderResult(
            groups: groupChainCalculator,
            groupLists: groupAssetCalculators,
            state: state
        )
    }

    private func filterAssets(
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
            let match = SearchMatch<ChainAsset>.matchInclusion(
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

    func assetState(from model: AssetListModel) -> AssetListState {
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

            self.model = model
            self.state = assetState(from: model)
            self.rebuildResult(for: self.query, filter: self.filter)
        }
    }
}
