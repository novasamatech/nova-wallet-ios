import Foundation
import Foundation_iOS

final class SubtensorStakingConfirmPresenter {
    weak var view: SubtensorStakingConfirmViewProtocol?
    let wireframe: SubtensorStakingConfirmWireframeProtocol
    let interactor: SubtensorConfirmInteractorInputProtocol

    let chainAsset: ChainAsset
    let model: SubtensorStakingConfirmModel
    let signing: SubtensorOperationGate.Verdict
    let viewModelFactory: SubtensorConfirmViewModelFactoryProtocol
    let dataValidationFactory: SubtensorStakingValidationFactoryProtocol
    let logger: LoggerProtocol

    var balance: AssetBalance?
    var price: PriceData?
    var fee: ExtrinsicFeeProtocol?
    var positionsState: Multistaking.SubtensorStakingState?
    var isPositionsSyncFailed = false
    var preflight: SubtensorStakingPreflight?
    var existentialDeposit: Balance?
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
        interactor: SubtensorConfirmInteractorInputProtocol,
        wireframe: SubtensorStakingConfirmWireframeProtocol,
        chainAsset: ChainAsset,
        model: SubtensorStakingConfirmModel,
        viewModelFactory: SubtensorConfirmViewModelFactoryProtocol,
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

            quoteState = SubtensorConfirmQuoteState(
                request: .buy(netuid: info.netuid, grossTao: model.amount, tolerance: tolerance),
                acknowledged: model.acknowledgedQuote
            )
        }

        self.localizationManager = localizationManager
    }
}

extension SubtensorStakingConfirmPresenter {
    var subnetName: String {
        SubtensorSubnetNaming.titleWithSymbol(for: model.target.netuid, in: catalogue, locale: selectedLocale)
    }

    var buyMoreCostBasis: SubtensorCostBasisState? {
        model.origin == .buyMore ? costBasis : nil
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
            direction: .buy,
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
            stakeBefore: isPositionsSyncFailed || positionsState == nil ? nil : stakeGroup().total,
            signing: signing,
            costBasis: buyMoreCostBasis
        )

        view?.didReceive(viewModel: viewModelFactory.createViewModel(for: input, locale: selectedLocale))
    }

    func stakeGroup() -> (total: Balance, hotkeyCount: Int) {
        guard let positionsState else {
            return (0, 0)
        }

        let portfolio = SubtensorPortfolioBuilder.build(state: positionsState)
        let groups = [portfolio.root].compactMap { $0 } + portfolio.subnets

        guard let group = groups.first(where: { $0.netuid == model.target.netuid }) else {
            return (0, 0)
        }

        return (group.totalAlpha, group.positions.count)
    }

    func refreshQuote() {
        guard let request = quoteState?.request else {
            return
        }

        interactor.refreshQuote(for: request)
    }

    func refreshFee() {
        guard let operation = createOperation(limitPrice: quoteState?.acknowledged?.limitPrice) else {
            refreshQuote()
            return
        }

        interactor.estimateFee(for: operation)
    }

    func refreshPreflight() {
        interactor.refreshPreflight(for: model.validator.hotkey, netuid: model.target.netuid)
    }

    func createOperation(limitPrice: Balance?) -> SubtensorStakingOperation? {
        guard !model.target.isRoot else {
            return .rootStake(hotkey: model.validator.hotkey, amount: model.amount)
        }

        guard let limitPrice else {
            return nil
        }

        return .subnetBuy(
            hotkey: model.validator.hotkey,
            netuid: model.target.netuid,
            grossTao: model.amount,
            limitPrice: limitPrice
        )
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
        guard let state = quoteState else {
            return createOperation(limitPrice: nil).map { ($0, nil) }
        }

        switch SubtensorConfirmTapRule.quoteVerdict(latest: state.latest, acknowledged: state.acknowledged) {
        case let .proceed(latest, limitPrice) where !state.isPriceMoved:
            return createOperation(limitPrice: limitPrice).map { ($0, latest) }
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

        let group = stakeGroup()

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
            stakeBefore: group.total,
            groupHotkeyCount: group.hotkeyCount,
            emptiesPosition: false,
            prices: SubtensorOperationResultPrices(taoPrice: price, alphaSpot: verified.quote?.quote.spotPrice),
            costBasis: buyMoreCostBasis
        )

        isHandingOff = true
        view?.didStartLoading()

        wireframe.showOperationResult(from: view, request: request, delegate: self)
    }

    func getValidationDependencies() -> SubtensorStakeValidatingDep {
        var dependencies = SubtensorStakeValidatingDep(
            amount: model.amount,
            balance: balance,
            fee: fee,
            existentialDeposit: existentialDeposit,
            preflight: preflight,
            netuid: model.target.netuid,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            onFeeRefresh: { [weak self] in
                self?.refreshFee()
            },
            onPreflightRefresh: { [weak self] in
                self?.refreshPreflight()
            }
        )

        if let quoteState {
            dependencies.quoteContext = SubtensorQuoteValidatingContext(
                latestQuote: quoteState.latest,
                acknowledgedLimit: quoteState.signingLimit,
                tradesUnavailable: tradesUnavailable,
                onQuoteRefresh: { [weak self] in
                    self?.refreshQuote()
                }
            )
        }

        return dependencies
    }

    func finishHandOff() {
        isHandingOff = false
        view?.didStopLoading()
    }
}

extension SubtensorStakingConfirmPresenter: SubtensorStakingConfirmPresenterProtocol {
    func setup() {
        seedSubnetData()
        provideAccountViewModels()
        provideTileIcons()
        provideViewModel()

        interactor.setup()

        refreshPreflight()

        if !model.target.isRoot {
            interactor.loadSubnetData()
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

        validateStake(
            for: getValidationDependencies(),
            dataValidationFactory: dataValidationFactory,
            selectedLocale: selectedLocale
        ) { [weak self] in
            self?.handOffAtTap()
        }
    }

    func selectAccount() {
        guard let address = model.account.chainAccount.toAddress() else {
            return
        }

        wireframe.showSubtensorInfo(.account(address: address, chain: chainAsset.chain), from: view)
    }

    func selectValidator() {
        guard model.target.isRoot || model.origin != .newPosition else {
            wireframe.showSubtensorInfo(.validator, from: view)
            return
        }

        wireframe.showValidatorInfo(from: view, target: model.target, hotkey: model.validator.hotkey, detail: nil)
    }

    func showSwapRateInfo() {
        wireframe.showSubtensorInfo(.swapRate(.buy, subnetName: subnetName), from: view)
    }

    func showSlippageInfo() {
        guard let tolerance = model.tolerance else {
            return
        }

        wireframe.showSubtensorInfo(.slippage(tolerance, canEdit: model.origin == .newPosition), from: view)
    }

    func showEarnPerMonthInfo() {
        wireframe.showSubtensorInfo(.earnTokensMonth(subnetName: subnetName), from: view)
    }

    func showAvgBuyPriceInfo() {
        let symbol = SubtensorSubnetNaming.symbol(for: model.target.netuid, in: catalogue)

        wireframe.showSubtensorInfo(.avgBuyPrice(symbol: symbol, subnetName: subnetName), from: view)
    }

    func showYouWillEarnInfo() {}

    func showNetworkFeeInfo() {
        wireframe.showSubtensorInfo(.networkFee(.buy), from: view)
    }
}

extension SubtensorStakingConfirmPresenter: SubtensorStakePresenterValidating {}
