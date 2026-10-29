import Foundation
import Foundation_iOS

final class SubtensorConfirmPresenter {
    weak var view: SubtensorConfirmViewProtocol?
    let wireframe: SubtensorConfirmWireframeProtocol
    let interactor: SubtensorBaseInteractorInputProtocol

    let chainAsset: ChainAsset
    let model: SubtensorConfirmModel
    let isWatchOnly: Bool
    let viewModelFactory: SubtensorConfirmViewModelFactory
    let dataValidationFactory: SubtensorValidationFactoryProtocol
    let logger: LoggerProtocol

    var balance: AssetBalance?
    var isBalanceLoaded = false
    var price: PriceData?
    var fee: ExtrinsicFeeProtocol?
    var shieldQuote: SubtensorShieldQuote?
    var shieldQuoteOperation: SubtensorOperation?
    var isShieldQuoteResolved = false
    var isShieldQuoteFallback = false
    var isShieldOn = true
    var positionsState: Multistaking.SubtensorState?
    var isPositionsSyncFailed = false
    var preflight: SubtensorPreflight?
    var existentialDeposit: Balance?
    var currentBlock: BlockNumber?
    var holds: [AccountId: SubtensorRootHold]?
    var quoteState: SubtensorConfirmQuoteState?
    var tradesUnavailable = false
    var catalogue: SubtensorSubnetCatalogue?
    var subnetLogos: SubtensorSubnetLogos?
    var costBasis: SubtensorCostBasisState = .loading
    let analytics: SubtensorConfirmAnalytics
    private(set) var isHandingOff = false

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: SubtensorBaseInteractorInputProtocol,
        wireframe: SubtensorConfirmWireframeProtocol,
        chainAsset: ChainAsset,
        model: SubtensorConfirmModel,
        viewModelFactory: SubtensorConfirmViewModelFactory,
        dataValidationFactory: SubtensorValidationFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.model = model
        isWatchOnly = model.account.chainAccount.type == .watchOnly
        isShieldQuoteResolved = model.isShieldQuoteFallback
        isShieldQuoteFallback = model.isShieldQuoteFallback
        self.viewModelFactory = viewModelFactory
        self.dataValidationFactory = dataValidationFactory
        self.logger = logger
        analytics = SubtensorConfirmAnalytics(model: model)

        if case let .subnet(info, _) = model.target {
            let tolerance = model.tolerance ?? SubtensorSlippageTolerance.defaultTolerance

            let request: SubtensorTradeQuoteRequest = model.direction == .buy
                ? .buy(netuid: info.netuid, grossTao: model.amount, tolerance: tolerance)
                : .sell(netuid: info.netuid, alpha: model.amount, tolerance: tolerance)

            quoteState = SubtensorConfirmQuoteState(request: request, acknowledged: model.acknowledgedQuote)
        }

        self.localizationManager = localizationManager
    }
}

extension SubtensorConfirmPresenter {
    var subnetName: String {
        SubtensorSubnetNaming.titleWithSymbol(for: model.target.netuid, in: catalogue, locale: selectedLocale)
    }

    var tracksCostBasis: Bool {
        model.origin == .buyMore || model.origin == .sell
    }

    func liveGroup() -> SubtensorPortfolioGroup? {
        positionsState.flatMap { SubtensorPortfolioBuilder.build(state: $0).group(netuid: model.target.netuid) }
    }

    func provideAccountViewModels() {
        do {
            let walletViewModel = try walletViewModelFactory.createDisplayViewModel(from: model.account)
            view?.didReceiveWallet(viewModel: walletViewModel)

            let accountViewModel = try walletViewModelFactory.createViewModel(from: model.account)
            view?.didReceiveAccount(viewModel: accountViewModel.rawDisplayAddress())
        } catch {
            logger.error("Wallet view model failed: \(error)")
        }

        let validatorViewModel = displayAddressViewModelFactory.createViewModel(from: model.validator.display)
        view?.didReceiveValidator(viewModel: validatorViewModel)
    }

    func provideTileIcons() {
        let viewModel = viewModelFactory.createTileIcons(
            for: model.target,
            direction: model.direction,
            catalogue: catalogue,
            subnetLogos: subnetLogos
        )

        view?.didReceiveTileIcons(viewModel: viewModel)
    }

    func provideViewModel() {
        let input = SubtensorConfirmViewModelInput(
            model: model,
            catalogue: catalogue,
            latestQuote: quoteState?.displayed,
            tradesUnavailable: tradesUnavailable,
            isQuoteFailed: quoteState?.isLatestFailed ?? false,
            isPriceMoved: quoteState?.isPriceMoved ?? false,
            price: price,
            fee: networkFee,
            stakeChange: createStakeChange(),
            isWatchOnly: isWatchOnly,
            costBasis: tracksCostBasis ? costBasis : nil
        )

        view?.didReceive(viewModel: viewModelFactory.createViewModel(for: input, locale: selectedLocale))
        analytics.syncPriceMoveBanner(isShown: input.isPriceMoved)
        provideShieldState()
    }

    func refreshQuote() {
        guard let request = quoteState?.request else {
            return
        }

        interactor.refreshQuote(for: request)
    }

    func refreshPreflight() {
        interactor.refreshPreflight(for: model.validator.hotkey, netuid: model.target.netuid)
    }

    func createOperation(limitPrice: Balance?, quote: SubtensorTradeQuote?) -> SubtensorOperation? {
        switch model.mode {
        case let .stake(amount):
            return createStakeOperation(amount: amount, limitPrice: limitPrice, quote: quote)
        case let .unstake(unstakeModel):
            return createUnstakeOperation(for: unstakeModel, limitPrice: limitPrice, quote: quote)
        }
    }

    func createQuoteContext() -> SubtensorQuoteValidatingContext? {
        guard let quoteState, let request = quoteState.request else {
            return nil
        }

        return SubtensorQuoteValidatingContext(
            latestQuote: quoteState.displayed,
            acknowledgedLimit: quoteState.acknowledged?.limitPrice,
            tradesUnavailable: tradesUnavailable,
            alphaDisplayInfo: chainAsset.assetDisplayInfo.subtensorAlpha(
                netuid: model.target.netuid,
                catalogue: catalogue
            ),
            loadingView: view,
            onQuoteRequest: { [weak self] completion in
                self?.interactor.requestValidatingQuote(for: request, completion: completion)
            },
            onQuoteUpdate: { [weak self] quote in
                self?.didReceiveQuote(quote)
            },
            onPriceMoved: { [weak self] quote in
                self?.applyMovedQuote(quote)
            },
            onQuoteVerified: { [weak self] quote in
                self?.applyVerifiedQuote(quote)
            }
        )
    }

    func applyVerifiedQuote(_ quote: SubtensorTradeQuote) {
        quoteState?.verify(quote)

        provideViewModel()
    }

    func applyMovedQuote(_ quote: SubtensorTradeQuote) {
        guard var state = quoteState, state.apply(latest: quote) else {
            return
        }

        state.raisePriceMoved()
        quoteState = state

        provideViewModel()
    }

    func applyTapGate() -> Bool {
        guard var state = quoteState else {
            return true
        }

        if state.isPriceMoved {
            analytics.acknowledgePriceMove(heldForNextTap: waitsForShieldQuote)
            state.acknowledgeLatest()
            quoteState = state

            refreshFeeAtTap()
            provideViewModel()

            return !waitsForShieldQuote
        }

        guard !state.raisePriceMovedIfCrossed() else {
            quoteState = state
            provideViewModel()
            return false
        }

        return true
    }

    func createVerifiedOperation() -> (operation: SubtensorOperation, quote: SubtensorTradeQuote?)? {
        guard isExitGroupUnchanged() else {
            presentGroupChanged()
            return nil
        }

        guard let state = quoteState else {
            return createOperation(limitPrice: nil, quote: nil).map { ($0, nil) }
        }

        guard let verified = state.verified, let limitPrice = state.signingLimit, !state.isPriceMoved else {
            return nil
        }

        return createOperation(limitPrice: limitPrice, quote: verified).map { ($0, verified) }
    }

    func handOffAtTap() {
        guard !isHandingOff, let fee = networkFee, let preflight, let verified = createVerifiedOperation() else {
            view?.didStopLoading()
            return
        }

        let group = liveGroup()

        let request = SubtensorOperationResultRequest(
            operation: verified.operation,
            shieldQuote: activeShieldQuote,
            origin: model.origin,
            account: model.account,
            target: model.target,
            payAmount: model.amount,
            quote: verified.quote,
            slippage: model.tolerance,
            validator: model.validator,
            estimatedNetworkFee: self.fee ?? fee,
            stakeBefore: group?.totalAlpha ?? 0,
            groupHotkeyCount: hotkeyCountAfterOperation(in: group),
            emptiesPosition: emptiesPosition(verified.operation, group: group),
            prices: SubtensorOperationResultPrices(taoPrice: price, alphaSpot: verified.quote?.quote.spotPrice),
            costBasis: tracksCostBasis ? costBasis : nil,
            blockTime: preflight.blockTime,
            hasLockedStake: model.hasLockedStake
        )

        isHandingOff = true
        view?.didStartLoading()

        trackConfirmed()
        wireframe.showOperationResult(from: view, request: request, delegate: self)
    }

    func finishHandOff() {
        isHandingOff = false
        view?.didStopLoading()
    }
}

extension SubtensorConfirmPresenter: SubtensorConfirmPresenterProtocol {
    func setup() {
        trackScreenOpened()
        provideAccountViewModels()
        provideTileIcons()
        provideViewModel()

        interactor.setup()
        interactor.loadExistentialDeposit()

        refreshPreflight()
        refreshHolds()

        if !model.target.isRoot {
            interactor.loadCatalogue()
            interactor.loadSubnetLogos()
            loadCostBasisIfNeeded()
            refreshQuote()
        }

        refreshFee()
    }

    func confirm() {
        analytics.beginTap()

        guard !isWatchOnly, !isHandingOff else {
            return
        }

        guard !tradesUnavailable else {
            analytics.reporter.tradesUnavailable()
            if let view {
                wireframe.presentSubnetTradesUnavailable(view, locale: selectedLocale)
            }

            return
        }

        guard applyTapGate() else {
            return
        }

        switch model.mode {
        case let .stake(amount):
            confirmStake(amount: amount)
        case let .unstake(unstakeModel):
            confirmUnstake(unstakeModel)
        }
    }

    func selectAccount() {
        guard let view, let address = model.account.chainAccount.toAddress() else {
            return
        }

        wireframe.presentAccountOptions(from: view, address: address, chain: chainAsset.chain, locale: selectedLocale)
    }

    func selectValidator() {
        guard model.target.isRoot || model.origin != .newPosition else {
            wireframe.showSubtensorInfo(.validator, from: view)
            return
        }

        wireframe.showValidatorInfo(from: view, target: model.target, hotkey: model.validator.hotkey, detail: nil)
    }

    func showSwapRateInfo() {
        guard let novaFeeRate = quoteState?.displayed?.novaFeeRate else {
            return
        }

        wireframe.showSubtensorInfo(
            .swapRate(model.direction, subnetName: subnetName, novaFeeRate: novaFeeRate),
            from: view
        )
    }

    func showSlippageInfo() {
        guard let tolerance = model.tolerance else {
            return
        }

        wireframe.showSubtensorInfo(.slippage(tolerance, canEdit: model.origin == .newPosition), from: view)
    }

    func showAvgBuyPriceInfo() {
        let symbol = SubtensorSubnetNaming.symbol(for: model.target.netuid, in: catalogue)

        wireframe.showSubtensorInfo(.avgBuyPrice(symbol: symbol, subnetName: subnetName), from: view)
    }

    func showYouWillEarnInfo() {
        wireframe.showSubtensorInfo(.youWillEarn, from: view)
    }

    func showNetworkFeeInfo() {
        wireframe.showSubtensorInfo(.networkFee(model.direction), from: view)
    }
}
