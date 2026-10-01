import Foundation
import Foundation_iOS

final class SubtensorUnstakeConfirmPresenter {
    weak var view: SubtensorUnstakeConfirmViewProtocol?
    let wireframe: SubtensorUnstakeConfirmWireframeProtocol
    let interactor: SubtensorUnstakeConfirmInputProtocol

    let chainAsset: ChainAsset
    let model: SubtensorUnstakeConfirmModel
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
    var currentBlock: BlockNumber?
    var holds: [AccountId: SubtensorRootHold]?
    var quoteState: SubtensorConfirmQuoteState?
    var tradesUnavailable = false
    var catalogue: SubtensorSubnetCatalogue?
    var subnetLogos: SubtensorSubnetLogos?
    var costBasis: SubtensorCostBasisState = .loading
    var isHandingOff = false
    private var isSignerNotSupportedShown = false

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: SubtensorUnstakeConfirmInputProtocol,
        wireframe: SubtensorUnstakeConfirmWireframeProtocol,
        chainAsset: ChainAsset,
        model: SubtensorUnstakeConfirmModel,
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
                request: .sell(netuid: info.netuid, alpha: model.unstakeModel.amount, tolerance: tolerance),
                acknowledged: model.acknowledgedQuote
            )
        }

        self.localizationManager = localizationManager
    }
}

extension SubtensorUnstakeConfirmPresenter {
    var unstakeModel: SubtensorUnstakeModel {
        model.unstakeModel
    }

    var subnetName: String {
        SubtensorSubnetNaming.titleWithSymbol(for: unstakeModel.netuid, in: catalogue, locale: selectedLocale)
    }

    func liveGroup() -> SubtensorPortfolioGroup? {
        guard let positionsState else {
            return nil
        }

        let portfolio = SubtensorPortfolioBuilder.build(state: positionsState)

        return ([portfolio.root].compactMap { $0 } + portfolio.subnets).first { $0.netuid == unstakeModel.netuid }
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
            direction: .sell,
            catalogue: catalogue,
            subnetLogos: subnetLogos
        )

        view?.didReceiveTileIcons(viewModel: viewModel)
    }

    func provideViewModel() {
        let input = SubtensorUnstakeConfirmViewModelInput(
            model: model,
            catalogue: catalogue,
            latestQuote: quoteState?.latest,
            tradesUnavailable: tradesUnavailable,
            isPriceMoved: quoteState?.isPriceMoved ?? false,
            price: price,
            fee: fee,
            stakeChange: createStakeChange(),
            signing: signing,
            costBasis: costBasis
        )

        view?.didReceive(viewModel: viewModelFactory.createViewModel(for: input, locale: selectedLocale))
    }

    func createStakeChange() -> SubtensorConfirmStakeChange? {
        guard model.target.isRoot, !isPositionsSyncFailed, let group = liveGroup() else {
            return nil
        }

        guard !unstakeModel.isFullUnstake else {
            return SubtensorConfirmStakeChange(before: group.totalAlpha, after: 0, isEstimated: false)
        }

        let remaining = group.totalAlpha.subtractOrZero(unstakeModel.amount)

        guard
            let feeAmount = fee?.amountForCurrentAccount,
            let transferable = balance?.transferable,
            transferable < feeAmount else {
            return SubtensorConfirmStakeChange(before: group.totalAlpha, after: remaining, isEstimated: false)
        }

        return SubtensorConfirmStakeChange(
            before: group.totalAlpha,
            after: remaining.subtractOrZero(feeAmount),
            isEstimated: true
        )
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
            exitHotkeys: unstakeModel.exitHotkeys,
            limitPrice: acknowledged?.limitPrice,
            quotedTaoOut: acknowledged?.quote.sim.taoAmount
        ) else {
            refreshQuote()
            return
        }

        interactor.estimateFee(for: operation)
    }

    func refreshPreflight() {
        interactor.refreshPreflight(for: unstakeModel.hotkey, netuid: unstakeModel.netuid)
    }

    func refreshHolds() {
        guard model.target.isRoot, let exitHotkeys = unstakeModel.exitHotkeys, exitHotkeys.count > 1 else {
            return
        }

        interactor.loadRootHolds(for: exitHotkeys)
    }

    func createOperation(
        exitHotkeys: [AccountId]?,
        limitPrice: Balance?,
        quotedTaoOut: Balance?
    ) -> SubtensorStakingOperation? {
        guard !model.target.isRoot else {
            return exitHotkeys.map { .rootUnstakeAll(hotkeys: $0) } ??
                .rootUnstake(hotkey: unstakeModel.hotkey, amount: unstakeModel.amount)
        }

        guard let limitPrice, let quotedTaoOut else {
            return nil
        }

        guard let exitHotkeys else {
            return .subnetSell(
                hotkey: unstakeModel.hotkey,
                netuid: unstakeModel.netuid,
                alpha: unstakeModel.amount,
                limitPrice: limitPrice,
                quotedTaoOut: quotedTaoOut
            )
        }

        return .subnetSellAll(
            hotkeys: exitHotkeys,
            netuid: unstakeModel.netuid,
            limitPrice: limitPrice,
            quotedTaoOut: quotedTaoOut
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

    func presentGroupChanged() {
        guard let view else {
            return
        }

        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        wireframe.present(
            message: nil,
            title: strings.stakingSubtensorAlertStaleTitle(),
            closeAction: strings.commonClose(),
            from: view
        )
    }
}

extension SubtensorUnstakeConfirmPresenter: SubtensorStakingConfirmPresenterProtocol {
    func setup() {
        provideAccountViewModels()
        provideTileIcons()
        provideViewModel()

        interactor.setup()

        refreshPreflight()
        refreshHolds()

        if !model.target.isRoot {
            interactor.loadSubnetData()
            interactor.loadCostBasis(for: unstakeModel.netuid)
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

        validateUnstake(
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
        wireframe.showValidatorInfo(from: view, target: model.target, hotkey: model.validator.hotkey, detail: nil)
    }

    func showSwapRateInfo() {
        wireframe.showSubtensorInfo(.swapRate(.sell, subnetName: subnetName), from: view)
    }

    func showSlippageInfo() {
        guard let tolerance = model.tolerance else {
            return
        }

        wireframe.showSubtensorInfo(.slippage(tolerance, canEdit: false), from: view)
    }

    func showEarnPerMonthInfo() {}

    func showAvgBuyPriceInfo() {
        let symbol = SubtensorSubnetNaming.symbol(for: unstakeModel.netuid, in: catalogue)

        wireframe.showSubtensorInfo(.avgBuyPrice(symbol: symbol, subnetName: subnetName), from: view)
    }

    func showYouWillEarnInfo() {
        wireframe.showSubtensorInfo(.youWillEarn, from: view)
    }

    func showNetworkFeeInfo() {
        wireframe.showSubtensorInfo(.networkFee(.sell), from: view)
    }
}

extension SubtensorUnstakeConfirmPresenter: SubtensorUnstakePresenterValidating {}
