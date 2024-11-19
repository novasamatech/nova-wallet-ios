import Foundation

struct AssetExchangeQuote {
    let route: AssetExchangeRoute
    let operationDescriptions: [AssetExchangeOperationDescription]
    let exchangeExecutionTimes: [TimeInterval]
}
