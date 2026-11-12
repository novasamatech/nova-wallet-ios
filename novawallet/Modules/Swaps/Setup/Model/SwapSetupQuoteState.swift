import Foundation

enum SwapSetupQuoteState: Equatable {
    case idle
    case loading(AssetConversion.Direction)
    case loaded
    case noRoute(AssetConversion.Direction)
    case failed(AssetConversion.Direction)

    init(quoteArgs: AssetConversion.QuoteArgs?, quoteResult: Result<AssetExchangeQuote, Error>?) {
        guard let quoteArgs else {
            self = .idle
            return
        }

        switch quoteResult {
        case .none:
            self = .loading(quoteArgs.direction)
        case .success:
            self = .loaded
        case let .failure(error):
            self = Self.isNoRoute(error) ? .noRoute(quoteArgs.direction) : .failed(quoteArgs.direction)
        }
    }

    static func isNoRoute(_ error: Error) -> Bool {
        if case .noRoute = error as? AssetsExchangeOperationFactoryError {
            return true
        }

        if case .noRoute = error as? AssetsExchangeServiceError {
            return true
        }

        return false
    }
}

struct SwapSetupSlippageViewModel: Equatable {
    let value: String
    let hasWarning: Bool
}
