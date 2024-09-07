import Foundation
import SubstrateSdk
import Operation_iOS
import SoraFoundation
import BigInt

struct VoteCardLoadErrorActions {
    let retry: () -> Void
}

final class VoteCardViewModel {
    weak var view: StackCardViewUpdatable?

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

    private let onVote: (VoteResult, ReferendumIdLocal) -> Void
    private let onBecomeTop: (ReferendumIdLocal) -> Void
    private let onLoadError: (VoteCardLoadErrorActions) -> Void

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
        onVote: @escaping (VoteResult, ReferendumIdLocal) -> Void,
        onBecomeTop: @escaping (ReferendumIdLocal) -> Void,
        onLoadError: @escaping (VoteCardLoadErrorActions) -> Void
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
        self.onVote = onVote
        self.onBecomeTop = onBecomeTop
        self.onLoadError = onLoadError
        self.currencyManager = currencyManager
    }

    func onAddToStack() {
        loadContent()
    }

    func onPop(direction: CardsZStack.DismissalDirection) {
        let voteResult = VoteResult(from: direction)

        onVote(voteResult, referendum.index)
    }

    func onBecomeTopView() {
        isTopMost = true

        if needsRetryLoad {
            loadContent()
        }

        onBecomeTop(referendum.index)
    }

    func onSetup() {
        makeSubscriptions()

        view?.setBackgroundGradient(model: gradient)
    }
}

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
            switch result {
            case let .success(model):
                guard let summary = model?.summary else {
                    return
                }

                self?.view?.setSummary(loadingState: .loaded(value: summary))
            case let .failure(error):
                self?.actionDetailsCancellable.cancel()
                self?.processLoadFailure()
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

        onLoadError(handlers)
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
