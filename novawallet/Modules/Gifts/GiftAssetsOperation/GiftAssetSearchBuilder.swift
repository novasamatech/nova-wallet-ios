import Foundation
import Operation_iOS

final class GiftAssetSearchBuilder: AssetSearchBuilder {
    private let assetTransferAggregationFactory: AssetTransferAggregationFactoryProtocol

    init(
        assetTransferAggregationFactory: AssetTransferAggregationFactoryProtocol,
        filter: ChainAssetsFilter?,
        workingQueue: DispatchQueue,
        callbackQueue: DispatchQueue,
        callbackClosure: @escaping (AssetSearchBuilderResult) -> Void,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.assetTransferAggregationFactory = assetTransferAggregationFactory

        super.init(
            filter: filter,
            workingQueue: workingQueue,
            callbackQueue: callbackQueue,
            callbackClosure: callbackClosure,
            operationQueue: operationQueue,
            logger: logger
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

        let resultWrapper: CompoundOperationWrapper<[ChainAsset]> = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else { return .createWithResult([]) }

            let chainAssets = try mapOperation.extractNoCancellableResultData()

            return assetTransferAggregationFactory.createCanPayFeeFilterWrapper(for: chainAssets)
        }

        resultWrapper.addDependency(operations: [mapOperation])

        return resultWrapper
            .insertingHead(operations: [mapOperation])
            .insertingHead(operations: chainAssetsWrapper.allOperations)
    }
}
