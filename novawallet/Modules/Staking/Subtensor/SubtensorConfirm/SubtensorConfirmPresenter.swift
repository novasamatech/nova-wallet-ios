import Foundation
import Foundation_iOS

final class SubtensorConfirmPresenter {
    weak var view: SubtensorConfirmViewProtocol?
    let wireframe: SubtensorConfirmWireframeProtocol
    let interactor: SubtensorStakingBaseInteractorInputProtocol

    let chainAsset: ChainAsset
    let model: SubtensorConfirmModel
    let signing: SubtensorOperationGate.Verdict
    let viewModelFactory: SubtensorConfirmViewModelFactory
    let dataValidationFactory: SubtensorStakingValidationFactoryProtocol
    let logger: LoggerProtocol

    var balance: AssetBalance?
    var price: PriceData?
    var fee: ExtrinsicFeeProtocol?
    var positionsState: Multistaking.SubtensorStakingState?
    var isPositionsSyncFailed = false
    var preflight: SubtensorStakingPreflight?
    var existentialDeposit: Balance?
    var currentBlock: BlockNumber?
    var holds: [AccountId: SubtensorRootHold]?
    var quoteState: SubtensorConfirmQuoteState?
    var tradesUnavailable = false
    var catalogue: SubtensorSubnetCatalogue?
    var subnetLogos: SubtensorSubnetLogos?
    var costBasis: SubtensorCostBasisState = .loading
    private(set) var isHandingOff = false
    private var isSignerNotSupportedShown = false

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: SubtensorStakingBaseInteractorInputProtocol,
        wireframe: SubtensorConfirmWireframeProtocol,
        chainAsset: ChainAsset,
        model: SubtensorConfirmModel,
        viewModelFactory: SubtensorConfirmViewModelFactory,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.model = model
        signing = SubtensorOperationGate.verdict(for: model.account.chainAccount.type)
        self.viewModelFactory = viewModelFactory
        self.dataValidationFactory = dataValidationFactory
        self.logger = logger

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
        guard let positionsState else {
            return nil
        }

        let portfolio = SubtensorPortfolioBuilder.build(state: positionsState)

        return ([portfolio.stakedRoot].compactMap { $0 } + portfolio.subnets).first { $0.netuid == model.target.netuid }
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
            latestQuote: quoteState?.latest,
            tradesUnavailable: tradesUnavailable,
            isQuoteFailed: quoteState?.isLatestFailed ?? false,
            isPriceMoved: quoteState?.isPriceMoved ?? false,
            price: price,
            fee: fee,
            stakeChange: createStakeChange(),
            signing: signing,
            costBasis: tracksCostBasis ? costBasis : nil
        )

        view?.didReceive(viewModel: viewModelFactory.createViewModel(for: input, locale: selectedLocale))
    }

    func createStakeChange() -> SubtensorConfirmStakeChange? {
        switch model.mode {
        case let .stake(amount):
            return createStakeChange(adding: amount)
        case let .unstake(unstakeModel):
            return createStakeChange(removing: unstakeModel)
        }
    }

    func refreshQuote() {
        guard let request = quoteState?.request else {
            return
        }

        interactor.refreshQuote(for: request)
    }

    func refreshFee() {
        let acknowledged = quoteState?.acknowledged

        guard let operation = createOperation(
            limitPrice: acknowledged?.limitPrice,
            quotedTaoOut: acknowledged?.quote.sim.taoAmount
        ) else {
            refreshQuote()
            return
        }

        interactor.estimateFee(for: operation)
    }

    func refreshPreflight() {
        interactor.refreshPreflight(for: model.validator.hotkey, netuid: model.target.netuid)
    }

    func createOperation(limitPrice: Balance?, quotedTaoOut: Balance?) -> SubtensorStakingOperation? {
        switch model.mode {
        case let .stake(amount):
            return createStakeOperation(amount: amount, limitPrice: limitPrice)
        case let .unstake(unstakeModel):
            return createUnstakeOperation(for: unstakeModel, limitPrice: limitPrice, quotedTaoOut: quotedTaoOut)
        }
    }

    func createQuoteContext() -> SubtensorQuoteValidatingContext? {
        quoteState.map { quoteState in
            SubtensorQuoteValidatingContext(
                latestQuote: quoteState.latest,
                acknowledgedLimit: quoteState.signingLimit,
                tradesUnavailable: tradesUnavailable,
                onQuoteRefresh: { [weak self] in
                    self?.refreshQuote()
                }
            )
        }
    }

    func presentQuoteMissing() {
        guard let view else {
            return
        }

        wireframe.presentQuoteMissing(view, onRetry: { [weak self] in
            self?.refreshQuote()
        }, locale: selectedLocale)
    }

    func applyTapGate() -> Bool {
        guard var state = quoteState else {
            return true
        }

        if state.isPriceMoved {
            guard state.acknowledgeLatest() else {
                presentQuoteMissing()
                return false
            }

            quoteState = state

            refreshFee()
            provideViewModel()

            return true
        }

        guard !state.raisePriceMovedIfCrossed() else {
            quoteState = state
            provideViewModel()
            return false
        }

        return true
    }

    func createVerifiedOperation() -> (operation: SubtensorStakingOperation, quote: SubtensorTradeQuote?)? {
        guard isExitGroupUnchanged() else {
            presentGroupChanged()
            return nil
        }

        guard let state = quoteState else {
            return createOperation(limitPrice: nil, quotedTaoOut: nil).map { ($0, nil) }
        }

        switch SubtensorConfirmTapRule.quoteVerdict(latest: state.latest, acknowledged: state.acknowledged) {
        case let .proceed(latest, limitPrice) where !state.isPriceMoved:
            return createOperation(
                limitPrice: limitPrice,
                quotedTaoOut: latest.quote.sim.taoAmount
            ).map { ($0, latest) }
        case .quoteMissing:
            presentQuoteMissing()
            return nil
        case .proceed, .priceMoved:
            quoteState?.raisePriceMoved()
            provideViewModel()
            return nil
        }
    }

    func handOffAtTap() {
        guard !isHandingOff, let fee, let verified = createVerifiedOperation() else {
            return
        }

        let group = liveGroup()

        let request = SubtensorOperationResultRequest(
            operation: verified.operation,
            origin: model.origin,
            account: model.account,
            target: model.target,
            payAmount: model.amount,
            quote: verified.quote,
            slippage: model.tolerance,
            validator: model.validator,
            estimatedNetworkFee: fee,
            stakeBefore: group?.totalAlpha ?? 0,
            groupHotkeyCount: group?.positions.count ?? 0,
            emptiesPosition: emptiesPosition(verified.operation, group: group),
            prices: SubtensorOperationResultPrices(taoPrice: price, alphaSpot: verified.quote?.quote.spotPrice),
            costBasis: tracksCostBasis ? costBasis : nil
        )

        isHandingOff = true
        view?.didStartLoading()

        wireframe.showOperationResult(from: view, request: request, delegate: self)
    }

    func finishHandOff() {
        isHandingOff = false
        view?.didStopLoading()
    }
}

extension SubtensorConfirmPresenter: SubtensorConfirmPresenterProtocol {
    func setup() {
        seedSubnetData()
        provideAccountViewModels()
        provideTileIcons()
        provideViewModel()

        interactor.setup()

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

    func didAppear() {
        guard case let .signerNotSupported(type) = signing, !isSignerNotSupportedShown, let view else {
            return
        }

        isSignerNotSupportedShown = true

        wireframe.presentSignerNotSupportedView(from: view, type: type) {}
    }

    func confirm() {
        guard signing == .allowed, !isHandingOff else {
            return
        }

        guard !tradesUnavailable else {
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
        wireframe.showSubtensorInfo(.swapRate(model.direction, subnetName: subnetName), from: view)
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
