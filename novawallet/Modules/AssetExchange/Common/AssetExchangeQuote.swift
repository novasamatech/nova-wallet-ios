import Foundation

struct AssetExchangeQuote {
    let route: AssetExchangeRoute
    let metaOperations: [AssetExchangeMetaOperationProtocol]
    let executionTimes: [TimeInterval]

    func totalExecutionTime() -> TimeInterval {
        executionTimes.reduce(0, +)
    }

    func totalExecutionTime(from index: Int) -> TimeInterval {
        executionTimes.dropFirst(index).reduce(0, +)
    }
}
