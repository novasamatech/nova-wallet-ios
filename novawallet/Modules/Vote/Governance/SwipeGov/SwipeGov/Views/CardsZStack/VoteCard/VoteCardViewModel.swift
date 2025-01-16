import Foundation
import SubstrateSdk
import Operation_iOS
import Foundation_iOS
import BigInt

struct VoteCardLoadErrorActions {
    let retry: () -> Void
}

typealias VoteCardId = ReferendumIdLocal

final class VoteCardViewModel: AnyProviderAutoCleaning {
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

    private let balanceViewModelFacade: BalanceViewModelFactoryFacadeProtocol

    private let chain: ChainModel
    private let referendum: ReferendumLocal

    private let summaryProcessor = VoteCardSummaryProcessor()
    private var cardSize: CGSize?

    private var priceProvider: StreamableProvider<PriceData>?
    private var price: PriceData?

    private let operationQueue: OperationQueue

    private let actions: Actions

    private var actionDetailsCancellable = CancellableCallStore()
    private var summaryCancellable = CancellableCallStore()

    private var amount: ReferendumActionLocal.Amount?
    private var isTopMost: Bool = false
    private var needsRetryLoad: Bool = false

    init(
        operationQueue: OperationQueue,
        summaryFetchOperationFactory: OpenGovSummaryOperationFactoryProtocol,
        amountOperationFactory: ReferendumAmountOperationFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        balanceViewModelFacade: BalanceViewModelFactoryFacadeProtocol,
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
        self.balanceViewModelFacade = balanceViewModelFacade
        self.chain = chain
        self.referendum = referendum
        self.gradient = gradient
        self.locale = locale
        self.actions = actions
        self.currencyManager = currencyManager
    }

    deinit {
        actionDetailsCancellable.cancel()
        summaryCancellable.cancel()
    }

    func onActionReadMore() {
        actions.onAction(referendum.index)
    }

    func onResize(for size: CGSize) {
        if cardSize != size, size.width > 0, size.height > 0 {
            cardSize = size
            loadSummary(for: size)
        }
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
        view?.setBackgroundGradient(model: gradient)
    }
}

// MARK: Private

private extension VoteCardViewModel {
    func loadContent() {
        if let cardSize {
            loadSummary(for: cardSize)
        }

        loadRequestedAmount()
    }

    func loadSummary(for size: CGSize) {
        summaryCancellable.cancel()

        view?.setSummary(loadingState: .loading)

        let summaryFetchOperation = summaryFetchOperationFactory.createSummaryOperation(for: referendum.index)

        let processingSummaryWrapper = summaryProcessor.createSummaryProcessingWrapper(
            for: {
                let optSummary = try summaryFetchOperation.extractNoCancellableResultData()
                return self.processSummary(optSummary?.summary)
            },
            size: size
        )

        processingSummaryWrapper.addDependency(operations: [summaryFetchOperation])

        let wrapper = processingSummaryWrapper.insertingHead(operations: [summaryFetchOperation])

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: summaryCancellable,
            runningCallbackIn: .main
        ) { [weak self] result in

            guard let self else { return }

            switch result {
            case let .success(model):
                view?.setSummary(loadingState: .loaded(value: model))
            case .failure:
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
            guard let self else {
                return
            }

            switch result {
            case let .success(amount):
                self.amount = amount
                self.updatePriceSubscription(
                    for: amount?.otherChainAssetOrCurrentUtility(from: self.chain)
                )
                self.updateRequestedAmount()
            case .failure:
                self.summaryCancellable.cancel()
                self.processLoadFailure()
            }
        }
    }

    func updateRequestedAmount() {
        guard
            let amount,
            let assetInfo = amount.otherChainAssetOrCurrentUtility(from: chain)?.assetDisplayInfo
        else {
            view?.setRequestedAmount(loadingState: .loaded(value: nil))
            return
        }

        let balanceViewModel = balanceViewModelFacade.balanceFromPrice(
            targetAssetInfo: assetInfo,
            amount: amount.value.decimal(assetInfo: assetInfo),
            priceData: price
        ).value(for: locale)

        view?.setRequestedAmount(loadingState: .loaded(value: balanceViewModel))
    }

    func updatePriceSubscription(for chainAsset: ChainAsset?) {
        price = nil
        clear(streamableProvider: &priceProvider)

        if let priceId = chainAsset?.asset.priceId {
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

        updateRequestedAmount()
    }
}

// MARK: SelectedCurrencyDepending

extension VoteCardViewModel: SelectedCurrencyDepending {
    func applyCurrency() {
        if view != nil {
            updateRequestedAmount()
        }
    }
}
