import Foundation
import Operation_iOS
import BigInt

protocol SubqueryRewardWrapperFactoryProtocol {
    func createOperation(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> CompoundOperationWrapper<SubqueryRewardOrSlashData>

    func createTotalRewardOperation(
        for address: AccountAddress,
        startTimestamp: Int64?,
        endTimestamp: Int64?,
        stakingType: SubqueryStakingType
    ) -> CompoundOperationWrapper<BigUInt>
}

final class SubqueryRewardAggregatingWrapperFactory {
    let factories: [SubqueryRewardOperationFactoryProtocol]

    init(factories: [SubqueryRewardOperationFactoryProtocol]) {
        self.factories = factories
    }
}

// MARK: - SubqueryRewardWrapperFactoryProtocol

extension SubqueryRewardAggregatingWrapperFactory: SubqueryRewardWrapperFactoryProtocol {
    func createOperation(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> CompoundOperationWrapper<SubqueryRewardOrSlashData> {
        let operations = factories.map {
            $0.createOperation(
                address: address,
                startTimestamp: startTimestamp,
                endTimestamp: endTimestamp
            )
        }

        let mergeOperation = ClosureOperation<SubqueryRewardOrSlashData> {
            let results = try operations.map { try $0.extractNoCancellableResultData() }
            let nodes: [SubqueryHistoryElement] = results.flatMap(\.historyElements.nodes)

            return SubqueryRewardOrSlashData(historyElements: .init(nodes: nodes))
        }

        operations.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: operations
        )
    }

    func createTotalRewardOperation(
        for address: AccountAddress,
        startTimestamp: Int64?,
        endTimestamp: Int64?,
        stakingType: SubqueryStakingType
    ) -> CompoundOperationWrapper<BigUInt> {
        let operations = factories.map {
            $0.createTotalRewardOperation(
                for: address,
                startTimestamp: startTimestamp,
                endTimestamp: endTimestamp,
                stakingType: stakingType
            )
        }

        let mergeOperation = ClosureOperation<BigUInt> {
            try operations
                .map { try $0.extractNoCancellableResultData() }
                .reduce(0, +)
        }

        operations.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: operations
        )
    }
}
