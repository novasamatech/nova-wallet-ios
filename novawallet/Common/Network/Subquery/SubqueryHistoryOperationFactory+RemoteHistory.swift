import Foundation
import Operation_iOS

extension SubqueryHistoryOperationFactory: WalletRemoteHistoryFactoryProtocol {
    func isComplete(pagination: Pagination) -> Bool {
        SubqueryHistoryContext(context: pagination.context ?? [:]).isComplete
    }

    func createOperationWrapper(
        for accountId: AccountId,
        chainFormat: ChainFormat,
        pagination: Pagination
    ) -> CompoundOperationWrapper<WalletRemoteHistoryData> {
        guard !isComplete(pagination: pagination) else {
            let result = WalletRemoteHistoryData(historyItems: [], context: pagination.context ?? [:])
            return CompoundOperationWrapper.createWithResult(result)
        }

        let subqueryContext = SubqueryHistoryContext(context: pagination.context ?? [:])

        let fetchOperation = createOperation(
            accountId: accountId,
            chainFormat: chainFormat,
            count: pagination.count,
            cursor: subqueryContext.cursor
        )

        let mapOperation = ClosureOperation<WalletRemoteHistoryData> {
            let subqueryData = try fetchOperation.extractNoCancellableResultData()

            let nextCursor = subqueryData.historyElements.pageInfo.endCursor
            let nextContext = SubqueryHistoryContext(cursor: nextCursor, isFirst: false).toContext()

            return WalletRemoteHistoryData(
                historyItems: subqueryData.historyElements.nodes,
                context: nextContext
            )
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [fetchOperation]
        )
    }
}
