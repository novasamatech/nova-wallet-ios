import BigInt
import Foundation
import Foundation_iOS

final class SubtensorUnstakeConfirmPresenter {
    weak var view: CollatorStkUnstakeConfirmViewProtocol?
    let wireframe: SubtensorUnstakeConfirmWireframeProtocol
    let interactor: SubtensorUnstakeConfirmInteractorInputProtocol

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let model: SubtensorUnstakeConfirmModel
    let dataValidationFactory: SubtensorStakingValidationFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let quoteViewModelFactory: SubtensorQuoteViewModelFactoryProtocol
    let logger: LoggerProtocol

    private(set) var fee: ExtrinsicFeeProtocol?
    private(set) var balance: AssetBalance?
    private(set) var price: PriceData?
    private(set) var positionsState: Multistaking.SubtensorStakingState?
    private(set) var claimable: SubtensorRootClaimable?
    private(set) var preflight: SubtensorStakingPreflight?
    private(set) var existentialDeposit: Balance?
    private(set) var currentBlock: BlockNumber?
    private(set) var quoteFlow = SubtensorQuoteFlowModel()
    private(set) var acknowledgedQuote: SubtensorTradeQuote?
    private(set) var tradesUnavailable = false
    private(set) var positionsSyncFailed = false

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: SubtensorUnstakeConfirmInteractorInputProtocol,
        wireframe: SubtensorUnstakeConfirmWireframeProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        model: SubtensorUnstakeConfirmModel,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        quoteViewModelFactory: SubtensorQuoteViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.model = model
        acknowledgedQuote = model.acknowledgedQuote
        self.dataValidationFactory = dataValidationFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.quoteViewModelFactory = quoteViewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

private extension SubtensorUnstakeConfirmPresenter {
    func stakedAmountInPlank() -> Balance {
        let positions = positionsState?.positions ?? []

        return positions.first {
            $0.netuid == model.unstakeModel.netuid && $0.hotkey == model.unstakeModel.hotkey
        }?.stakeAlpha ?? model.unstakeModel.amount
    }

    func unstakingAmount() -> Balance {
        model.unstakeModel.isFullUnstake ? stakedAmountInPlank() : model.unstakeModel.amount
    }

    var quoteView: SubtensorUnstakeConfirmViewProtocol? {
        view as? SubtensorUnstakeConfirmViewProtocol
    }

    var tolerance: BigRational {
        model.tolerance ?? SubtensorSlippageTolerance.defaultTolerance
    }

    func quoteRequest() -> SubtensorTradeQuoteRequest? {
        let amount = unstakingAmount()

        guard case let .subnet(info, _) = model.target, amount > 0 else {
            return nil
        }

        return .sell(netuid: info.netuid, alpha: amount, tolerance: tolerance)
    }

    func feeOperation() -> SubtensorStakingOperation? {
        let unstakeModel = model.unstakeModel

        guard !model.target.isRoot else {
            if let exitHotkeys = unstakeModel.exitHotkeys {
                return .rootUnstakeAll(hotkeys: exitHotkeys)
            }

            return .rootUnstake(hotkey: unstakeModel.hotkey, amount: unstakeModel.amount)
        }

        let limitPrice = acknowledgedQuote?.limitPrice ??
            model.target.unstakeLimitPrice(spot: model.target.listedPrice, tolerance: tolerance)

        let amount = unstakingAmount()
        let listedTaoOut = model.target.listedPrice.map { amount * $0 / SubtensorStakingPallet.alphaPriceScale }

        guard
            let limitPrice,
            let quotedTaoOut = quoteFlow.freshQuote?.quote.sim.taoAmount ?? listedTaoOut,
            quotedTaoOut > 0 else {
            return nil
        }

        return createSubnetOperation(
            exitHotkeys: unstakeModel.exitHotkeys,
            limitPrice: limitPrice,
            quotedTaoOut: quotedTaoOut
        )
    }

    func createSubnetOperation(
        exitHotkeys: [AccountId]?,
        limitPrice: Balance,
        quotedTaoOut: Balance
    ) -> SubtensorStakingOperation {
        let unstakeModel = model.unstakeModel

        if let exitHotkeys {
            return .subnetSellAll(
                hotkeys: exitHotkeys,
                netuid: unstakeModel.netuid,
                limitPrice: limitPrice,
                quotedTaoOut: quotedTaoOut
            )
        } else {
            return .subnetSell(
                hotkey: unstakeModel.hotkey,
                netuid: unstakeModel.netuid,
                alpha: unstakeModel.amount,
                limitPrice: limitPrice,
                quotedTaoOut: quotedTaoOut
            )
        }
    }

    func createOperationAtTap() -> SubtensorStakingOperation? {
        let unstakeModel = model.unstakeModel

        let exitHotkeys: [AccountId]?

        if unstakeModel.isFullUnstake {
            guard let positionsState else {
                presentStalePositions()
                return nil
            }

            let verified = SubtensorConfirmTapRule.verifiedExitHotkeys(for: unstakeModel, in: positionsState)

            guard let verified else {
                presentGroupChanged()
                return nil
            }

            exitHotkeys = verified
        } else {
            exitHotkeys = nil
        }

        guard !model.target.isRoot else {
            if let exitHotkeys {
                return .rootUnstakeAll(hotkeys: exitHotkeys)
            }

            return .rootUnstake(hotkey: unstakeModel.hotkey, amount: unstakeModel.amount)
        }

        switch SubtensorConfirmTapRule.quoteVerdict(latest: quoteFlow.freshQuote, acknowledged: acknowledgedQuote) {
        case let .proceed(latest, acknowledged):
            return createSubnetOperation(
                exitHotkeys: exitHotkeys,
                limitPrice: acknowledged.limitPrice,
                quotedTaoOut: latest.quote.sim.taoAmount
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

    func presentStalePositions() {
        guard let view else {
            return
        }

        wireframe.presentStalePositions(view, onRetry: { [weak self] in
            self?.interactor.refreshPositions()
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
        } else {
            _ = quoteFlow.updateRequest(request)
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

    func provideAmountViewModel() {
        let displayInfo = model.target.assetDisplayInfo(basedOn: chainAsset.assetDisplayInfo)

        let amountDecimal = unstakingAmount().decimal(assetInfo: displayInfo)

        let viewModel: BalanceViewModelProtocol

        if model.target.isRoot {
            viewModel = balanceViewModelFactory.balanceFromPrice(
                amountDecimal,
                priceData: price
            ).value(for: selectedLocale)
        } else {
            let amountString = AssetBalanceFormatterFactory().createTokenFormatter(
                for: displayInfo
            ).value(for: selectedLocale).stringFromDecimal(amountDecimal) ?? ""

            viewModel = BalanceViewModel(amount: amountString, price: nil)
        }

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

    func provideHints() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        var hints = [strings.stakingSubtensorHintUnstakeInstant()]

        if !model.target.isRoot {
            hints.append(strings.stakingSubtensorHintSimulatedReceive())
        }

        view?.didReceiveHints(viewModel: hints)
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
        provideHints()
        provideQuoteViewModel()
        provideSlippageViewModel()
    }

    func getValidationDependencies() -> SubtensorUnstakeValidatingDep {
        SubtensorUnstakeValidatingDep(
            netuid: model.unstakeModel.netuid,
            accountId: selectedAccount.chainAccount.accountId,
            amount: unstakingAmount(),
            positionAlpha: stakedAmountInPlank(),
            availability: preflight?.stakeAvailability,
            exitHotkeys: model.unstakeModel.exitHotkeys,
            balance: balance,
            fee: fee,
            existentialDeposit: existentialDeposit,
            preflight: preflight,
            holds: nil,
            currentBlock: currentBlock,
            blockTime: chainAsset.chain.defaultBlockTimeMillis ?? SubtensorStakingFlowConstants.blockTimeMillis,
            assetDisplayInfo: model.target.assetDisplayInfo(basedOn: chainAsset.assetDisplayInfo),
            syncFailed: positionsSyncFailed,
            onFeeRefresh: { [weak self] in
                self?.refreshFee()
            },
            onPreflightRefresh: { [weak self] in
                guard let self else {
                    return
                }

                interactor.refreshPreflight(for: model.unstakeModel.hotkey, netuid: model.unstakeModel.netuid)
            },
            onPositionsRefresh: { [weak self] in
                self?.interactor.refreshPositions()
            },
            onUnstakeAll: nil,
            quoteContext: getQuoteContext()
        )
    }

    func createSuccessTitle(
        for outcome: SubtensorStakingOperationOutcome
    ) -> ExtrinsicSubmissionPresentingParams.Title {
        guard let tao = outcome.executed?.tao, tao > 0 else {
            return .general(selectedLocale)
        }

        let amountDecimal = tao.decimal(assetInfo: chainAsset.assetDisplayInfo)
        let amountString = balanceViewModelFactory.amountFromValue(
            amountDecimal
        ).value(for: selectedLocale)

        let title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.stakingSubtensorSuccessUnstakedFormat(amountString)

        return .preferred(title)
    }
}

extension SubtensorUnstakeConfirmPresenter: CollatorStkUnstakeConfirmPresenterProtocol {
    func setup() {
        applyCurrentState()

        interactor.setup()

        interactor.refreshPreflight(for: model.unstakeModel.hotkey, netuid: model.unstakeModel.netuid)

        updateQuoteOnEntry()

        refreshFee()
    }

    func selectAccount() {
        guard
            let address = selectedAccount.chainAccount.toAddress(),
            let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }

    func selectCollator() {
        guard let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: model.validator.display.address,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }

    func confirm() {
        validateUnstake(
            for: getValidationDependencies(),
            dataValidationFactory: dataValidationFactory,
            selectedLocale: selectedLocale
        ) { [weak self] in
            self?.submitAtTap()
        }
    }
}

extension SubtensorUnstakeConfirmPresenter: SubtensorUnstakePresenterValidating {}

extension SubtensorUnstakeConfirmPresenter: SubtensorUnstakeConfirmInteractorOutputProtocol {
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

        provideAmountViewModel()

        updateQuoteOnEntry()
    }

    func didReceivePositionsSyncFailed(_ isFailed: Bool) {
        logger.debug("Positions sync failed: \(isFailed)")

        positionsSyncFailed = isFailed
    }

    func didReceiveClaimable(_ claimable: SubtensorRootClaimable?) {
        logger.debug("Claimable: \(String(describing: claimable))")

        self.claimable = claimable
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

                interactor.refreshPreflight(for: model.unstakeModel.hotkey, netuid: model.unstakeModel.netuid)
            }
        case .quoteFailed:
            quoteFlow.clearQuote()
            provideQuoteViewModel()
        }
    }
}

extension SubtensorUnstakeConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            applyCurrentState()
        }
    }
}
