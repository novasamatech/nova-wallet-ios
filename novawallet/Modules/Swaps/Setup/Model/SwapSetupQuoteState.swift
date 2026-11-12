import Foundation
import SubstrateSdk

enum SwapSetupQuoteState: Equatable {
    case idle
    case loading(AssetConversion.Direction)
    case loaded
    case noRoute(AssetConversion.Direction)
    case noLiquidity(AssetConversion.Direction)
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
            switch SwapQuoteFailure(error: error) {
            case .noRoute:
                self = .noRoute(quoteArgs.direction)
            case .noLiquidity:
                self = .noLiquidity(quoteArgs.direction)
            case .fetchFailed:
                self = .failed(quoteArgs.direction)
            }
        }
    }
}

enum SwapQuoteFailureAlertState {
    case armed
    case pending
    case ended
}

enum SwapQuoteFailure: Equatable {
    case noRoute
    case noLiquidity
    case fetchFailed

    init(error: Error) {
        if Self.isNoRoute(error) {
            self = .noRoute
        } else if Self.isFetchFailure(error) {
            self = .fetchFailed
        } else {
            self = .noLiquidity
        }
    }
}

private extension SwapQuoteFailure {
    static func isNoRoute(_ error: Error) -> Bool {
        if case .noRoute = error as? AssetsExchangeOperationFactoryError {
            return true
        }

        if case .noRoute = error as? AssetsExchangeServiceError {
            return true
        }

        return false
    }

    static func isFetchFailure(_ error: Error) -> Bool {
        switch error {
        case is URLError, is JSONRPCOperationError:
            return true
        case let engineError as JSONRPCEngineError:
            return isFetchFailure(engineError)
        case let registryError as ChainRegistryError:
            return isFetchFailure(registryError)
        default:
            return false
        }
    }

    static func isFetchFailure(_ error: JSONRPCEngineError) -> Bool {
        switch error {
        case .remoteCancelled, .unknownError, .emptyResult:
            true
        case .clientCancelled, .unsupportedMethod:
            false
        }
    }

    static func isFetchFailure(_ error: ChainRegistryError) -> Bool {
        switch error {
        case .connectionUnavailable, .runtimeMetadaUnavailable:
            true
        case .noChain, .noChainAsset, .noUtilityAsset:
            false
        }
    }
}

struct SwapSetupSlippageViewModel: Equatable {
    let value: String
    let hasWarning: Bool
}
