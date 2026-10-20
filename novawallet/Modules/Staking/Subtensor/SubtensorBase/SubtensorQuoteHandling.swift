import Foundation
import Foundation_iOS

protocol SubtensorBaseRetrying: AnyObject, Localizable {
    var retryView: ControllerBackedProtocol? { get }
    var retryWireframe: AlertPresentable & FeeRetryable & CommonRetryable { get }
    var retryInteractor: SubtensorBaseInteractorInputProtocol { get }

    func refreshFee()
    func refreshPreflight()
}

extension SubtensorBaseRetrying {
    func presentBaseRetry(for error: SubtensorBaseError) {
        switch error {
        case .feeFailed:
            retryWireframe.presentFeeStatus(on: retryView, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        case .preflightFailed:
            retryWireframe.presentRequestStatus(on: retryView, locale: selectedLocale) { [weak self] in
                self?.refreshPreflight()
            }
        case .rootHoldsFailed:
            retryWireframe.presentRequestStatus(on: retryView, locale: selectedLocale) { [weak self] in
                self?.retryInteractor.retryRootHolds()
            }
        case .existentialDepositFailed:
            retryWireframe.presentRequestStatus(on: retryView, locale: selectedLocale) { [weak self] in
                self?.retryInteractor.loadExistentialDeposit()
            }
        case .quoteFailed:
            break
        }
    }
}

protocol SubtensorQuoteHandling: SubtensorBaseRetrying {
    var chainAsset: ChainAsset { get }
    var inputResult: AmountInputResult? { get set }
    var quoteFlow: SubtensorQuoteFlowModel { get set }
    var acceptedQuote: SubtensorTradeQuote? { get set }
    var isQuoteFailed: Bool { get set }
    var tradesUnavailable: Bool { get set }
    var isRoot: Bool { get }
    var logger: LoggerProtocol { get }
    var quoteInteractor: SubtensorBaseInteractorInputProtocol { get }
    var loadingView: LoadableViewProtocol? { get }
    var alphaDisplayInfo: AssetBalanceDisplayInfo { get }
    var dataAnalytics: SubtensorDataAnalytics { get }

    func inputAmount() -> Balance?
    func quoteRequest() -> SubtensorTradeQuoteRequest?
    func applyInputChange()
    func provideAmountInputViewModel()
    func provideViewModel()
}

extension SubtensorQuoteHandling {
    var retryInteractor: SubtensorBaseInteractorInputProtocol { quoteInteractor }

    func updateAmount(_ newValue: Decimal?) {
        inputResult = newValue.map { .absolute($0) }

        applyInputChange()
    }

    func selectMax() {
        inputResult = .rate(1)

        provideAmountInputViewModel()
        applyInputChange()
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))

        provideAmountInputViewModel()
        applyInputChange()
    }

    func inputAmountOrPlaceholder() -> Balance {
        inputAmount().flatMap { $0 > 0 ? $0 : nil } ??
            Decimal(1).toSubstrateAmount(precision: chainAsset.assetDisplayInfo.assetPrecision) ?? 1
    }

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

    func createQuoteContext() -> SubtensorQuoteValidatingContext? {
        guard !isRoot, let request = quoteRequest() else {
            return nil
        }

        let latestQuote = quoteFlow.freshQuote
        acceptedQuote = nil

        return SubtensorQuoteValidatingContext(
            latestQuote: latestQuote,
            acknowledgedLimit: latestQuote?.limitPrice,
            tradesUnavailable: tradesUnavailable,
            alphaDisplayInfo: alphaDisplayInfo,
            loadingView: loadingView,
            onQuoteRequest: { [weak self] completion in
                self?.quoteInteractor.requestValidatingQuote(for: request, completion: completion)
            },
            onQuoteUpdate: { [weak self] quote in
                self?.acceptedQuote = quote
                self?.didReceiveQuote(quote)
            }
        )
    }

    func acknowledgedQuote(for context: SubtensorQuoteValidatingContext?) -> SubtensorTradeQuote? {
        acceptedQuote ?? context?.latestQuote
    }

    func didReceiveQuote(_ quote: SubtensorTradeQuote) {
        guard quoteFlow.applyQuote(quote) else {
            return
        }

        tradesUnavailable = false
        isQuoteFailed = false

        provideViewModel()
    }

    func didReceiveBaseError(_ error: SubtensorBaseError) {
        logger.error("Subtensor setup error: \(error)")
        dataAnalytics.trackFailure(error)

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
