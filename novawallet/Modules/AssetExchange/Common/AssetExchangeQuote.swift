import Foundation

struct AssetExchangeQuote {
    let route: AssetExchangeRoute
    let metaOperations: [AssetExchangeMetaOperationProtocol]
    let executionTimes: [TimeInterval]

    func totalExecutionTime() -> TimeInterval {
        executionTimes.reduce(0, +)
    }
}
