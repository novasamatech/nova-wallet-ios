import Foundation
import BigInt
import Operation_iOS

final class GiftAssetSearchBuilder: AssetSearchBuilder {
    private let assetTransferAggregationFactory: AssetTransferAggregationFactoryProtocol
    private let sufficiencyProvider: AssetExchangeSufficiencyProviding

    init(
        assetTransferAggregationFactory: AssetTransferAggregationFactoryProtocol,
        sufficiencyProvider: AssetExchangeSufficiencyProviding,
        filter: ChainAssetsFilter?,
        workingQueue: DispatchQueue,
        callbackQueue: DispatchQueue,
        callbackClosure: @escaping (AssetSearchBuilderResult) -> Void,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.assetTransferAggregationFactory = assetTransferAggregationFactory
        self.sufficiencyProvider = sufficiencyProvider

        super.init(
            filter: filter,
            workingQueue: workingQueue,
            callbackQueue: callbackQueue,
            callbackClosure: callbackClosure,
            operationQueue: operationQueue,
            logger: logger
        )
    }

    override func assetListState(from model: AssetListModel) -> AssetListState {
        let chainAssets = model.allChains.flatMap { _, chain in
            chain.assets.map { ChainAssetId(chainId: chain.chainId, assetId: $0.assetId) }
        }

        let balanceResults = chainAssets.reduce(into: [ChainAssetId: Result<BigUInt, Error>]()) {
            switch model.balances[$1] {
            case let .success(amount):
                $0[$1] = .success(amount.transferable)
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
            externalBalances: nil
        )
    }

    override func createFilterWrapper(
        for query: String,
        filter: ChainAssetsFilter?,
        chains: [ChainModel.Id: ChainModel]
    ) -> CompoundOperationWrapper<[ChainAsset]> {
        let chainAssetsWrapper = super.createFilterWrapper(
            for: query,
            filter: filter,
            chains: chains
        )

        let mapOperation: ClosureOperation<[ChainModel: [ChainAsset]]> = ClosureOperation {
            try chainAssetsWrapper
                .targetOperation
                .extractNoCancellableResultData()
                .reduce(into: [:]) { $0[$1.chain] = ($0[$1.chain] ?? []) + [$1] }
        }

        mapOperation.addDependency(chainAssetsWrapper.targetOperation)

        let canPayFeeFilterWrapper: CompoundOperationWrapper<[ChainAsset]>
        canPayFeeFilterWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else { return .createWithResult([]) }

            let chainAssets = try mapOperation.extractNoCancellableResultData()

            return assetTransferAggregationFactory.createCanPayFeeFilterWrapper(for: chainAssets)
        }

        canPayFeeFilterWrapper.addDependency(operations: [mapOperation])

        let resultOperation = ClosureOperation {
            let canPayFeeAssets = try canPayFeeFilterWrapper.targetOperation.extractNoCancellableResultData()

            return canPayFeeAssets.filter { self.sufficiencyProvider.isSufficient(asset: $0.asset) }
        }

        resultOperation.addDependency(canPayFeeFilterWrapper.targetOperation)

        let dependencies = canPayFeeFilterWrapper.allOperations
            + [mapOperation]
            + chainAssetsWrapper.allOperations

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: dependencies
        )
    }
}
