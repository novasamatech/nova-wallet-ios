import Foundation
import Foundation_iOS

protocol SubtensorBaseRetrying: AnyObject, Localizable {
    var retryView: ControllerBackedProtocol? { get }
    var retryWireframe: AlertPresentable & FeeRetryable & CommonRetryable { get }

    func refreshFee()
    func refreshPreflight()
}

extension SubtensorBaseRetrying {
    func presentBaseRetry(for error: SubtensorStakingBaseError) {
        switch error {
        case .feeFailed:
            retryWireframe.presentFeeStatus(on: retryView, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        case .preflightFailed:
            retryWireframe.presentRequestStatus(on: retryView, locale: selectedLocale) { [weak self] in
                self?.refreshPreflight()
            }
        case .quoteFailed:
            break
        }
    }
}

protocol SubtensorQuoteHandling: SubtensorBaseRetrying {
    var quoteFlow: SubtensorQuoteFlowModel { get set }
    var isQuoteFailed: Bool { get set }
    var tradesUnavailable: Bool { get set }
    var logger: LoggerProtocol { get }
    var quoteInteractor: SubtensorStakingBaseInteractorInputProtocol { get }

    func quoteRequest() -> SubtensorTradeQuoteRequest?
    func provideViewModel()
}

extension SubtensorQuoteHandling {
    func updateQuote() {
        if let request = quoteFlow.updateRequest(quoteRequest()) {
            isQuoteFailed = false
            quoteInteractor.refreshQuote(for: request)
        }
    }

    func forceQuoteRefresh() {
        let request = quoteRequest()

        _ = quoteFlow.updateRequest(request)

        if let request {
            quoteInteractor.refreshQuote(for: request)
        }
    }

    func didReceiveQuote(_ quote: SubtensorTradeQuote) {
        guard quoteFlow.applyQuote(quote) else {
            return
        }

        tradesUnavailable = false
        isQuoteFailed = false

        provideViewModel()
    }

    func didReceiveBaseError(_ error: SubtensorStakingBaseError) {
        logger.error("Subtensor setup error: \(error)")

        if error.isNovaFeeUnavailable {
            tradesUnavailable = true
        }

        guard case .quoteFailed = error else {
            presentBaseRetry(for: error)
            return
        }

        quoteFlow.clearQuote()
        isQuoteFailed = true
        provideViewModel()
    }
}
