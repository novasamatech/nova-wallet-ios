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
    private(set) var currentBlock: BlockNumber?
    private(set) var quoteFlow = SubtensorQuoteFlowModel()

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

    func quoteArgs() -> SubtensorQuoteArgs? {
        SubtensorQuoteFlowModel.unstakeArgs(for: model.target, amount: unstakingAmount())
    }

    /// the submitted limit follows the freshest spot so the tolerance protects against
    /// movement after the last quote, not after the setup screen
    func currentUnstakeModel() -> SubtensorUnstakeModel {
        guard !model.target.isRoot else {
            return model.unstakeModel
        }

        let spot = quoteFlow.freshQuote?.spotPrice ?? model.quote?.spotPrice ?? model.target.listedPrice

        let tolerance = model.slippage ?? SubtensorSlippageTolerance.defaultTolerance

        let limitPrice = model.target.unstakeLimitPrice(spot: spot, tolerance: tolerance)
            ?? model.unstakeModel.limitPrice

        return SubtensorUnstakeModel(
            hotkey: model.unstakeModel.hotkey,
            netuid: model.unstakeModel.netuid,
            amount: model.unstakeModel.amount,
            isFullUnstake: model.unstakeModel.isFullUnstake,
            limitPrice: limitPrice
        )
    }

    func updateQuoteOnEntry() {
        guard let args = quoteArgs() else {
            return
        }

        if quoteFlow.args == nil {
            _ = quoteFlow.updateArgs(args)

            if let seed = model.quote {
                _ = quoteFlow.applyQuote(seed)
            }
        } else {
            _ = quoteFlow.updateArgs(args)
        }

        interactor.refreshQuote(for: args)

        provideQuoteViewModel()
        provideSlippageViewModel()
    }

    func forceQuoteRefresh() {
        guard let args = quoteArgs() else {
            return
        }

        if quoteFlow.updateArgs(args) != nil {
            provideQuoteViewModel()
        }

        interactor.refreshQuote(for: args)
    }

    func provideQuoteViewModel() {
        let viewModel = quoteViewModelFactory.createQuotePanel(
            for: quoteFlow.freshQuote,
            target: model.target,
            locale: selectedLocale
        )

        quoteView?.didReceiveQuote(viewModel: viewModel)
    }

    func provideSlippageViewModel() {
        guard let slippage = model.slippage else {
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
            args: quoteArgs(),
            quote: quoteFlow.freshQuote,
            limitPrice: currentUnstakeModel().limitPrice,
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
        let viewModel = displayAddressViewModelFactory.createViewModel(from: model.delegate)
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

        interactor.estimateFee(for: .unstake(currentUnstakeModel()))
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
            amount: unstakingAmount(),
            stakedAmount: stakedAmountInPlank(),
            isFullUnstake: model.unstakeModel.isFullUnstake,
            balance: balance,
            fee: fee,
            preflight: preflight,
            claimablePayout: claimable?.payout(for: model.unstakeModel.hotkey),
            currentBlock: currentBlock,
            blockTime: chainAsset.chain.defaultBlockTimeMillis ?? SubtensorStakingFlowConstants.blockTimeMillis,
            assetDisplayInfo: model.target.assetDisplayInfo(basedOn: chainAsset.assetDisplayInfo),
            onFeeRefresh: { [weak self] in
                self?.refreshFee()
            },
            onPreflightRefresh: { [weak self] in
                guard let self else {
                    return
                }

                interactor.refreshPreflight(for: model.unstakeModel.hotkey, netuid: model.unstakeModel.netuid)
            },
            // the amount here is already quoted and confirmed, so switching it behind the
            // user would invalidate everything the screen is showing
            onUnstakeAll: nil,
            quoteContext: getQuoteContext()
        )
    }

    func createSuccessTitle(
        for submission: SubtensorSubmissionModel
    ) -> ExtrinsicSubmissionPresentingParams.Title {
        guard case let .unstaked(tao, _, _) = submission.outcome, tao > 0 else {
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
            address: model.delegate.address,
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
            guard let self else {
                return
            }

            view?.didStartLoading()

            interactor.submit(call: .unstake(currentUnstakeModel()))
        }
    }
}

extension SubtensorUnstakeConfirmPresenter: SubtensorUnstakePresenterValidating {}

extension SubtensorUnstakeConfirmPresenter: SubtensorUnstakeConfirmInteractorOutputProtocol {
    func didReceiveSubmissionResult(_ result: Result<SubtensorSubmissionModel, Error>) {
        view?.didStopLoading()

        switch result {
        case let .success(submission):
            wireframe.complete(
                on: view,
                sender: submission.submitted.sender,
                title: createSuccessTitle(for: submission)
            )
        case let .failure(error):
            logger.error("Submission error: \(error)")

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

    func didReceiveClaimable(_ claimable: SubtensorRootClaimable?) {
        logger.debug("Claimable: \(String(describing: claimable))")

        self.claimable = claimable
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        logger.debug("Block number: \(blockNumber)")

        currentBlock = blockNumber

        forceQuoteRefresh()
    }

    func didReceiveQuote(_ quote: SubtensorQuote) {
        logger.debug("Quote: \(quote)")

        guard quoteFlow.applyQuote(quote) else {
            return
        }

        provideQuoteViewModel()
    }

    func didReceivePreflight(_ preflight: SubtensorStakingPreflight) {
        logger.debug("Preflight: \(preflight)")

        self.preflight = preflight
    }

    func didReceiveExistentialDeposit(_ deposit: Balance) {
        logger.debug("Existential deposit: \(deposit)")
    }

    func didReceiveBaseError(_ error: SubtensorStakingBaseError) {
        logger.error("Error: \(error)")

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
