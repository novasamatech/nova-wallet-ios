import Foundation
import SubstrateSdk
import Operation_iOS
import SoraFoundation
import BigInt

struct VoteCardLoadErrorActions {
    let retry: () -> Void
}

typealias VoteCardId = ReferendumIdLocal

final class VoteCardViewModel {
    struct Actions {
        let onAction: (ReferendumIdLocal) -> Void
        let onVote: (VoteResult, ReferendumIdLocal) -> Void
        let onBecomeTop: (ReferendumIdLocal) -> Void
        let onLoadError: (VoteCardLoadErrorActions) -> Void
    }

    weak var view: StackCardViewUpdatable?

    var id: VoteCardId {
        referendum.index
    }

    let locale: Locale
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    private let gradient: GradientModel

    private let summaryFetchOperationFactory: OpenGovSummaryOperationFactoryProtocol
    private let amountOperationFactory: ReferendumAmountOperationFactoryProtocol

    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    private let chain: ChainModel
    private let referendum: ReferendumLocal

    private var priceProvider: StreamableProvider<PriceData>?
    private var price: PriceData?

    private let operationQueue: OperationQueue

    private let actions: Actions

    private var actionDetailsCancellable = CancellableCallStore()
    private var summaryCancellable = CancellableCallStore()

    private var amount: BigUInt?
    private var isTopMost: Bool = false
    private var needsRetryLoad: Bool = false

    init(
        operationQueue: OperationQueue,
        summaryFetchOperationFactory: OpenGovSummaryOperationFactoryProtocol,
        amountOperationFactory: ReferendumAmountOperationFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        chain: ChainModel,
        referendum: ReferendumLocal,
        currencyManager: CurrencyManagerProtocol,
        gradient: GradientModel,
        locale: Locale,
        actions: Actions
    ) {
        self.operationQueue = operationQueue
        self.summaryFetchOperationFactory = summaryFetchOperationFactory
        self.amountOperationFactory = amountOperationFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chain = chain
        self.referendum = referendum
        self.gradient = gradient
        self.locale = locale
        self.actions = actions
        self.currencyManager = currencyManager
    }

    func onActionReadMore() {
        actions.onAction(referendum.index)
    }

    func onAddToStack() {
        loadContent()
    }

    func onPop(direction: CardsZStack.DismissalDirection) {
        let voteResult = VoteResult(from: direction)

        actions.onVote(voteResult, referendum.index)
    }

    func onBecomeTopView() {
        isTopMost = true

        if needsRetryLoad {
            loadContent()
        }

        actions.onBecomeTop(referendum.index)
    }

    func onSetup() {
        makeSubscriptions()

        view?.setBackgroundGradient(model: gradient)
    }
}

// MARK: Private

private extension VoteCardViewModel {
    func loadContent() {
        loadSummary()
        loadRequestedAmount()
    }

    func loadSummary() {
        guard !summaryCancellable.hasCall else {
            return
        }

        view?.setSummary(loadingState: .loading)

        let summaryFetchOperation = summaryFetchOperationFactory.createSummaryOperation(for: referendum.index)

        execute(
            operation: summaryFetchOperation,
            inOperationQueue: operationQueue,
            backingCallIn: summaryCancellable,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self else { return }

            switch result {
            case let .success(model):
                let summary = processSummary(model?.summary)
                view?.setSummary(loadingState: .loaded(value: summary))
            case let .failure(error):
                actionDetailsCancellable.cancel()
                processLoadFailure()
            }
        }
    }

    func loadRequestedAmount() {
        guard !actionDetailsCancellable.hasCall else {
            return
        }

        view?.setRequestedAmount(loadingState: .loading)

        let wrapper = amountOperationFactory.createWrapper()

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: actionDetailsCancellable,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(amount):
                self?.updateRequestedAmount(amount: amount)
            case let .failure(error):
                self?.summaryCancellable.cancel()
                self?.processLoadFailure()
            }
        }
    }

    func updateRequestedAmount(amount: BigUInt?) {
        guard
            let amount,
            let precision = chain.utilityAssetDisplayInfo()?.assetPrecision,
            let decimalAmount = Decimal.fromSubstrateAmount(
                amount,
                precision: precision
            )
        else {
            view?.setRequestedAmount(loadingState: .loaded(value: nil))
            return
        }

        self.amount = amount

        let balanceViewModel = balanceViewModelFactory.balanceFromPrice(
            decimalAmount,
            priceData: price
        ).value(for: locale)

        view?.setRequestedAmount(loadingState: .loaded(value: balanceViewModel))
    }

    func makeSubscriptions() {
        if let priceId = chain.utilityAsset()?.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }

    func processLoadFailure() {
        guard isTopMost else {
            needsRetryLoad = true

            return
        }

        let handlers = VoteCardLoadErrorActions(
            retry: { [weak self] in self?.loadContent() }
        )

        actions.onLoadError(handlers)
    }

    func processSummary(_ summary: String?) -> String {
        if let summary, !summary.isEmpty {
            summary
        } else {
            R.string.localizable.govReferendumTitleFallback(
                "\(id)",
                preferredLanguages: locale.rLanguages
            )
        }
    }
}

// MARK: PriceLocalStorageSubscriber

extension VoteCardViewModel: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(
        result: Result<PriceData?, any Error>,
        priceId _: AssetModel.PriceId
    ) {
        guard let price = try? result.get() else {
            return
        }

        self.price = price

        updateRequestedAmount(amount: amount)
    }
}

// MARK: SelectedCurrencyDepending

extension VoteCardViewModel: SelectedCurrencyDepending {
    func applyCurrency() {
        if let priceId = chain.utilityAsset()?.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }
}
