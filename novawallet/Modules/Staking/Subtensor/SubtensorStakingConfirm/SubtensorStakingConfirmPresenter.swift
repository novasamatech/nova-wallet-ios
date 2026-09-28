import BigInt
import Foundation
import Foundation_iOS

final class SubtensorStakingConfirmPresenter {
    weak var view: CollatorStakingConfirmViewProtocol?
    let wireframe: SubtensorStakingConfirmWireframeProtocol
    let interactor: SubtensorStakingConfirmInteractorInputProtocol

    let selectedAccount: MetaChainAccountResponse
    let chainAsset: ChainAsset
    let model: SubtensorStakingConfirmModel
    let logger: LoggerProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let quoteViewModelFactory: SubtensorQuoteViewModelFactoryProtocol
    let dataValidationFactory: SubtensorStakingValidationFactoryProtocol

    private(set) var balance: AssetBalance?
    private(set) var price: PriceData?
    private(set) var fee: ExtrinsicFeeProtocol?
    private(set) var positionsState: Multistaking.SubtensorStakingState?
    private(set) var preflight: SubtensorStakingPreflight?
    private(set) var existentialDeposit: Balance?
    private(set) var currentBlock: BlockNumber?
    private(set) var quoteFlow = SubtensorQuoteFlowModel()
    private(set) var acknowledgedQuote: SubtensorTradeQuote?
    private(set) var tradesUnavailable = false

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()
    private lazy var takeFormatter = NumberFormatter.percentSingle.localizableResource()

    init(
        interactor: SubtensorStakingConfirmInteractorInputProtocol,
        wireframe: SubtensorStakingConfirmWireframeProtocol,
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        model: SubtensorStakingConfirmModel,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        quoteViewModelFactory: SubtensorQuoteViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.model = model
        acknowledgedQuote = model.acknowledgedQuote
        self.dataValidationFactory = dataValidationFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.quoteViewModelFactory = quoteViewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

private extension SubtensorStakingConfirmPresenter {
    func provideAmountViewModel() {
        let viewModel = balanceViewModelFactory.balanceFromPrice(
            model.amount.decimal(assetInfo: chainAsset.assetDisplayInfo),
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAmount(viewModel: viewModel)
    }

    func provideWalletViewModel() {
        do {
            let viewModel = try walletViewModelFactory.createDisplayViewModel(from: selectedAccount)
            view?.didReceiveWallet(viewModel: viewModel)
        } catch {
            logger.error("Did receive error: \(error)")
        }
    }

    func provideAccountViewModel() {
        do {
            let viewModel = try walletViewModelFactory.createViewModel(from: selectedAccount)
            view?.didReceiveAccount(viewModel: viewModel.rawDisplayAddress())
        } catch {
            logger.error("Did receive error: \(error)")
        }
    }

    func provideFeeViewModel() {
        let viewModel: BalanceViewModelProtocol? = fee.map { value in
            let amountDecimal = value.amount.decimal(assetInfo: chainAsset.assetDisplayInfo)

            return balanceViewModelFactory.balanceFromPrice(
                amountDecimal,
                priceData: price
            ).value(for: selectedLocale).approximatelyForSubtensorFee()
        }

        view?.didReceiveFee(viewModel: viewModel)
    }

    func provideDelegateViewModel() {
        let viewModel = displayAddressViewModelFactory.createViewModel(from: model.validator.display)
        view?.didReceiveCollator(viewModel: viewModel)
    }

    func provideHintsViewModel() {
        let languages = selectedLocale.rLanguages
        let strings = R.string(preferredLanguages: languages).localizable

        var hints: [String]

        if case let .subnet(info, _) = model.target {
            let symbol = info.displaySymbol

            hints = [
                strings.stakingSubtensorHintBuyStakeFormat(
                    symbol.isEmpty ? "SN\(info.netuid)" : symbol
                ),
                strings.stakingSubtensorHintAlphaCompound()
            ]
        } else {
            hints = [strings.stakingSubtensorHintManualClaim()]
        }

        if
            let take = preflight?.delegateTake,
            let takeString = takeFormatter.value(for: selectedLocale).stringFromDecimal(
                Decimal(take) / Decimal(UInt16.max)
            ) {
            hints.append(strings.stakingSubtensorHintTakeFormat(takeString))
        }

        view?.didReceiveHints(viewModel: hints)
    }

    var quoteView: SubtensorStakingConfirmViewProtocol? {
        view as? SubtensorStakingConfirmViewProtocol
    }

    var tolerance: BigRational {
        model.tolerance ?? SubtensorSlippageTolerance.defaultTolerance
    }

    func quoteRequest() -> SubtensorTradeQuoteRequest? {
        guard case let .subnet(info, _) = model.target, model.amount > 0 else {
            return nil
        }

        return .buy(netuid: info.netuid, grossTao: model.amount, tolerance: tolerance)
    }

    func feeOperation() -> SubtensorStakingOperation? {
        guard !model.target.isRoot else {
            return .rootStake(hotkey: model.validator.hotkey, amount: model.amount)
        }

        let limitPrice = acknowledgedQuote?.limitPrice ??
            model.target.stakeLimitPrice(spot: model.target.listedPrice, tolerance: tolerance)

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

    func createOperationAtTap() -> SubtensorStakingOperation? {
        guard !model.target.isRoot else {
            return .rootStake(hotkey: model.validator.hotkey, amount: model.amount)
        }

        switch SubtensorConfirmTapRule.quoteVerdict(latest: quoteFlow.freshQuote, acknowledged: acknowledgedQuote) {
        case let .proceed(_, acknowledged):
            return .subnetBuy(
                hotkey: model.validator.hotkey,
                netuid: model.target.netuid,
                grossTao: model.amount,
                limitPrice: acknowledged.limitPrice
            )
        case .quoteMissing:
            presentQuoteMissing()
            return nil
        case .priceMoved:
            presentPriceMoved()
            return nil
        }
    }

    func presentQuoteMissing() {
        guard let view else {
            return
        }

        wireframe.presentQuoteMissing(view, onRetry: { [weak self] in
            self?.forceQuoteRefresh()
        }, locale: selectedLocale)
    }

    func presentPriceMoved() {
        guard let view else {
            return
        }

        wireframe.presentOrderBeyondTolerance(view, locale: selectedLocale)
    }

    func submitAtTap() {
        guard let operation = createOperationAtTap() else {
            return
        }

        view?.didStartLoading()

        interactor.submit(operation: operation)
    }

    func updateQuoteOnEntry() {
        guard let request = quoteRequest() else {
            return
        }

        if quoteFlow.request == nil {
            _ = quoteFlow.updateRequest(request)

            if let seed = model.acknowledgedQuote {
                _ = quoteFlow.applyQuote(seed)
            }
        }

        interactor.refreshQuote(for: request)

        provideQuoteViewModel()
        provideSlippageViewModel()
    }

    func forceQuoteRefresh() {
        guard let request = quoteRequest() else {
            return
        }

        if quoteFlow.updateRequest(request) != nil {
            provideQuoteViewModel()
        }

        interactor.refreshQuote(for: request)
    }

    func provideQuoteViewModel() {
        let viewModel = quoteViewModelFactory.createQuotePanel(
            for: quoteFlow.freshQuote?.quote,
            target: model.target,
            locale: selectedLocale
        )

        quoteView?.didReceiveQuote(viewModel: viewModel)
    }

    func provideSlippageViewModel() {
        guard let slippage = model.tolerance else {
            quoteView?.didReceiveSlippage(viewModel: nil)
            return
        }

        let viewModel = quoteViewModelFactory.createSlippageViewModel(
            for: slippage,
            locale: selectedLocale
        )

        quoteView?.didReceiveSlippage(viewModel: viewModel)
    }

    func getQuoteContext() -> SubtensorQuoteValidatingContext? {
        guard !model.target.isRoot else {
            return nil
        }

        return SubtensorQuoteValidatingContext(
            latestQuote: quoteFlow.freshQuote,
            acknowledgedLimit: acknowledgedQuote?.limitPrice,
            tradesUnavailable: tradesUnavailable,
            onQuoteRefresh: { [weak self] in
                self?.forceQuoteRefresh()
            }
        )
    }

    func refreshFee() {
        fee = nil
        provideFeeViewModel()

        guard let operation = feeOperation() else {
            return
        }

        interactor.estimateFee(for: operation)
    }

    func applyCurrentState() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFeeViewModel()
        provideDelegateViewModel()
        provideHintsViewModel()
        provideQuoteViewModel()
        provideSlippageViewModel()
    }

    func presentOptions(for address: AccountAddress) {
        guard let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }

    func getValidationDependencies() -> SubtensorStakeValidatingDep {
        SubtensorStakeValidatingDep(
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
                guard let self else {
                    return
                }

                interactor.refreshPreflight(for: model.validator.hotkey, netuid: model.target.netuid)
            },
            quoteContext: getQuoteContext()
        )
    }

    func createSuccessTitle(
        for outcome: SubtensorStakingOperationOutcome
    ) -> ExtrinsicSubmissionPresentingParams.Title {
        guard let executed = outcome.executed, executed.tao > 0 else {
            return .general(selectedLocale)
        }

        let tao = executed.tao
        let alpha = executed.alpha
        let netuid = executed.netuid

        let amountString: String

        if netuid != SubtensorStakingPallet.rootNetuid {
            let displayInfo = model.target.assetDisplayInfo(basedOn: chainAsset.assetDisplayInfo)
            let amountDecimal = alpha.decimal(assetInfo: displayInfo)

            amountString = AssetBalanceFormatterFactory().createTokenFormatter(
                for: displayInfo
            ).value(for: selectedLocale).stringFromDecimal(amountDecimal) ?? ""
        } else {
            let amountDecimal = tao.decimal(assetInfo: chainAsset.assetDisplayInfo)

            amountString = balanceViewModelFactory.amountFromValue(
                amountDecimal
            ).value(for: selectedLocale)
        }

        let title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.stakingSubtensorSuccessStakedFormat(amountString)

        return .preferred(title)
    }
}

extension SubtensorStakingConfirmPresenter: CollatorStakingConfirmPresenterProtocol {
    func setup() {
        applyCurrentState()

        interactor.setup()

        interactor.refreshPreflight(for: model.validator.hotkey, netuid: model.target.netuid)

        updateQuoteOnEntry()

        refreshFee()
    }

    func selectAccount() {
        guard let address = selectedAccount.chainAccount.toAddress() else {
            return
        }

        presentOptions(for: address)
    }

    func selectCollator() {
        presentOptions(for: model.validator.display.address)
    }

    func confirm() {
        validateStake(
            for: getValidationDependencies(),
            dataValidationFactory: dataValidationFactory,
            selectedLocale: selectedLocale
        ) { [weak self] in
            self?.submitAtTap()
        }
    }
}

extension SubtensorStakingConfirmPresenter: SubtensorStakePresenterValidating {}

extension SubtensorStakingConfirmPresenter: SubtensorStakingConfirmInteractorOutputProtocol {
    func didReceiveSubmissionResult(
        _ result: Result<SubtensorStakingOperationOutcome, SubtensorStakingSubmissionFailure>
    ) {
        view?.didStopLoading()

        switch result {
        case let .success(outcome):
            wireframe.complete(
                on: view,
                sender: .current(selectedAccount.chainAccount),
                title: createSuccessTitle(for: outcome)
            )
        case let .failure(failure):
            logger.error("Submission error: \(failure)")

            let error = failure.error

            applyCurrentState()
            refreshFee()
            forceQuoteRefresh()

            wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
                error,
                view: view,
                closeAction: .dismiss,
                locale: selectedLocale,
                completionClosure: nil
            )
        }
    }

    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        logger.debug("Balance: \(String(describing: balance))")

        self.balance = balance
    }

    func didReceivePrice(_ priceData: PriceData?) {
        logger.debug("Price: \(String(describing: priceData))")

        price = priceData

        provideAmountViewModel()
        provideFeeViewModel()
    }

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        logger.debug("Fee: \(fee)")

        self.fee = fee

        provideFeeViewModel()
    }

    func didReceivePositions(_ state: Multistaking.SubtensorStakingState?) {
        logger.debug("Positions: \(String(describing: state))")

        positionsState = state
    }

    func didReceivePositionsSyncFailed(_ isFailed: Bool) {
        logger.debug("Positions sync failed: \(isFailed)")
    }

    func didReceiveClaimable(_ claimable: SubtensorRootClaimable?) {
        logger.debug("Claimable: \(String(describing: claimable))")
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        logger.debug("Block number: \(blockNumber)")

        currentBlock = blockNumber

        forceQuoteRefresh()
    }

    func didReceiveQuote(_ quote: SubtensorTradeQuote) {
        logger.debug("Quote: \(quote)")

        guard quoteFlow.applyQuote(quote) else {
            return
        }

        tradesUnavailable = false

        if acknowledgedQuote == nil {
            acknowledgedQuote = quote
        }

        provideQuoteViewModel()
    }

    func didReceivePreflight(_ preflight: SubtensorStakingPreflight) {
        logger.debug("Preflight: \(preflight)")

        self.preflight = preflight

        provideHintsViewModel()
    }

    func didReceiveExistentialDeposit(_ deposit: Balance) {
        logger.debug("Existential deposit: \(deposit)")

        existentialDeposit = deposit
    }

    func didReceiveBaseError(_ error: SubtensorStakingBaseError) {
        logger.error("Error: \(error)")

        if error.isNovaFeeUnavailable {
            tradesUnavailable = true
        }

        switch error {
        case .feeFailed:
            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        case .preflightFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                guard let self else {
                    return
                }

                interactor.refreshPreflight(for: model.validator.hotkey, netuid: model.target.netuid)
            }
        case .quoteFailed:
            quoteFlow.clearQuote()
            provideQuoteViewModel()
        }
    }
}

extension SubtensorStakingConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideAmountViewModel()
            provideFeeViewModel()
            provideHintsViewModel()
        }
    }
}
