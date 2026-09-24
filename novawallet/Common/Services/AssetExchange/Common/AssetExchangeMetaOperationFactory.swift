import Foundation

struct AssetExchangeMetaOperationFactory {
    struct Result {
        let operations: [AssetExchangeMetaOperationProtocol]
        let indexByEdge: [Int]

        func netAmountOut(commission: AssetExchangeCommission?) -> Balance {
            let chargingOperationIndex = commission.flatMap { commission in
                indexByEdge.indices.contains(commission.chargingEdgeIndex)
                    ? indexByEdge[commission.chargingEdgeIndex]
                    : nil
            }

            return AssetExchangeCommissionNetFlow(
                operations: operations,
                commission: commission,
                chargingOperationIndex: chargingOperationIndex
            ).netFinalAmountOut
        }
    }

    func createMetaOperations(for route: AssetExchangeRoute) throws -> Result {
        var operations: [AssetExchangeMetaOperationProtocol] = []
        var indexByEdge: [Int] = []

        for segment in route.items {
            let amountIn = segment.amountIn(for: route.direction)
            let amountOut = segment.amountOut(for: route.direction)

            if
                let lastOperation = operations.last,
                let newOperation = try segment.edge.appendToMetaOperation(
                    lastOperation,
                    amountIn: amountIn,
                    amountOut: amountOut
                ) {
                operations[operations.count - 1] = newOperation
            } else {
                operations.append(try segment.edge.beginMetaOperation(for: amountIn, amountOut: amountOut))
            }

            indexByEdge.append(operations.count - 1)
        }

        return Result(operations: operations, indexByEdge: indexByEdge)
    }
}
