import Foundation

final class AssetExchangeOperationPrototypeFactory {
    func createOperationPrototypes(
        from path: AssetExchangeGraphPath
    ) throws -> [AssetExchangeOperationPrototypeProtocol] {
        try path.reduce([]) { curOperations, edge in
            if
                let lastOperation = curOperations.last,
                let newOperation = try edge.appendToOperationPrototype(
                    lastOperation
                ) {
                return curOperations.dropLast() + [newOperation]
            } else {
                let newOperation = try edge.beginOperationPrototype()
                return curOperations + [newOperation]
            }
        }
    }
}
