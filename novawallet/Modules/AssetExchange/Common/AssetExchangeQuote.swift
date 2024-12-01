import Foundation

struct AssetExchangeQuote {
    let route: AssetExchangeRoute
    let metaOperations: [AssetExchangeMetaOperationProtocol]
    let executionTimes: [TimeInterval]

    func totalExecutionTime() -> TimeInterval {
        executionTimes.reduce(0, +)
    }

    func totalExecutionTime(from index: Int) -> TimeInterval {
        let subarray = if index > 0 {
            Array(executionTimes.dropFirst(index))
        } else {
            executionTimes
        }

        return subarray.reduce(0, +)
    }
}
