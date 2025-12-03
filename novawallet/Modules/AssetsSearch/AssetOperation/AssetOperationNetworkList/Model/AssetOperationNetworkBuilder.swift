import Foundation
import Operation_iOS
import BigInt

struct AssetOperationNetworkBuilderResult {
    let assets: [AssetListAssetModel]
    let prices: [ChainAssetId: PriceData]
    let state: AssetListState
}

class AssetOperationNetworkBuilder {
    let workingQueue: DispatchQueue
    let callbackQueue: DispatchQueue
    let callbackClosure: (AssetOperationNetworkBuilderResult?) -> Void
    let logger: LoggerProtocol

    private var chainAssets: [ChainAsset] = []
    private var state: AssetListState?

    init(
        chainAssets: [ChainAsset],
        workingQueue: DispatchQueue,
        callbackQueue: DispatchQueue,
        callbackClosure: @escaping (AssetOperationNetworkBuilderResult?) -> Void,
        logger: LoggerProtocol
    ) {
        self.chainAssets = chainAssets
        self.workingQueue = workingQueue
        self.callbackQueue = callbackQueue
        self.callbackClosure = callbackClosure
        self.logger = logger
    }

    private func rebuildResult() {
        guard let state = state else {
            return
        }

        let result = createResult(
            from: chainAssets,
            state: state
        )

        callbackQueue.async {
            self.callbackClosure(result)
        }
    }

    private func createResult(
        from assets: [ChainAsset],
        state: AssetListState
    ) -> AssetOperationNetworkBuilderResult? {
        guard let prices = try? state.priceResult?.get() else {
            return nil
        }

        var assetModels = assets.map { chainAsset in
            AssetListModelHelpers.createAssetModel(
                for: chainAsset.chain,
                assetModel: chainAsset.asset,
                state: state
            )
        }

        let comparator = AssetListModelHelpers.assetSortByUtilityThenPriority

        assetModels.sort(by: comparator)

        return AssetOperationNetworkBuilderResult(
            assets: assetModels,
            prices: prices,
            state: state
        )
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
}

extension AssetOperationNetworkBuilder {
    func apply(chainAssets: [ChainAsset]) {
        workingQueue.async { [weak self] in
            guard let self else { return }

            self.chainAssets = chainAssets
            rebuildResult()
        }
    }

    func apply(model: AssetListModel) {
        workingQueue.async { [weak self] in
            guard let self else { return }

            state = assetListState(from: model)
            rebuildResult()
        }
    }
}
