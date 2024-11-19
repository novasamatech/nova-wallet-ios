import Foundation

struct AssetExchangeQuote {
    let route: AssetExchangeRoute
    let metaOperations: [AssetExchangeMetaOperationProtocol]
    let executionTimes: [TimeInterval]
}
