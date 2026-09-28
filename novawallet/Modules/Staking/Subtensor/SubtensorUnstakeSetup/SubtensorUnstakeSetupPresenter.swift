import BigInt
import Foundation
import Foundation_iOS

final class SubtensorUnstakeSetupPresenter {
    weak var view: CollatorStkPartialUnstakeSetupViewProtocol?
    let wireframe: SubtensorUnstakeSetupWireframeProtocol
    let interactor: SubtensorUnstakeSetupInteractorInputProtocol
    let logger: LoggerProtocol

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let flowNetuid: UInt16
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    let accountDetailsViewModelFactory: CollatorStakingAccountViewModelFactoryProtocol
    let quoteViewModelFactory: SubtensorQuoteViewModelFactoryProtocol
    let dataValidationFactory: SubtensorStakingValidationFactoryProtocol

    private(set) var inputResult: AmountInputResult?
    private(set) var fee: ExtrinsicFeeProtocol?
    private(set) var balance: AssetBalance?
    private(set) var price: PriceData?
    private(set) var positionsState: Multistaking.SubtensorStakingState?
    private(set) var claimable: SubtensorRootClaimable?
    private(set) var preflight: SubtensorStakingPreflight?
    private(set) var existentialDeposit: Balance?
    private(set) var delegateDisplayAddress: DisplayAddress?
    private(set) var delegateIdentities: [AccountId: AccountIdentity]?
    private(set) var currentBlock: BlockNumber?
    private(set) var positionsSyncFailed = false

    private(set) var selectedTarget: SubtensorStakeTarget?
    private(set) var slippage: BigRational = SubtensorSlippageTolerance.defaultTolerance
    private(set) var quoteFlow = SubtensorQuoteFlowModel()
    private(set) var tradesUnavailable = false
    private var cachedInputBalanceViewModelFactory: BalanceViewModelFactoryProtocol?

    init(
        interactor: SubtensorUnstakeSetupInteractorInputProtocol,
        wireframe: SubtensorUnstakeSetupWireframeProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        accountDetailsViewModelFactory: CollatorStakingAccountViewModelFactoryProtocol,
        quoteViewModelFactory: SubtensorQuoteViewModelFactoryProtocol,
        initialPosition: SubtensorStakingPosition?,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.dataValidationFactory = dataValidationFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.priceAssetInfoFactory = priceAssetInfoFactory
        self.accountDetailsViewModelFactory = accountDetailsViewModelFactory
        self.quoteViewModelFactory = quoteViewModelFactory
        self.logger = logger

        flowNetuid = initialPosition?.netuid ?? SubtensorStakingPallet.rootNetuid

        if flowNetuid == SubtensorStakingPallet.rootNetuid {
            selectedTarget = .root
        }

        if
            let initialPosition,
            let address = try? initialPosition.hotkey.toAddress(using: chainAsset.chain.chainFormat) {
            delegateDisplayAddress = DisplayAddress(address: address, username: "")
        }

        self.localizationManager = localizationManager
    }
}

extension SubtensorUnstakeSetupPresenter {
    var unstakeBasis: SubtensorUnstakeBasis {
        SubtensorUnstakeBasis.make(
            staked: stakedAmountInPlank(),
            availability: preflight?.stakeAvailability
        )
    }
}

private extension SubtensorUnstakeSetupPresenter {
    var isRootFlow: Bool {
        flowNetuid == SubtensorStakingPallet.rootNetuid
    }

    var quoteView: SubtensorUnstakeSetupViewProtocol? {
        view as? SubtensorUnstakeSetupViewProtocol
    }

    func getDelegateAccount() -> AccountId? {
        try? delegateDisplayAddress?.address.toAccountId(using: chainAsset.chain.chainFormat)
    }

    func flowPositions() -> [SubtensorStakingPosition] {
        (positionsState?.positions ?? []).filter { $0.netuid == flowNetuid }
    }

    func inputDisplayInfo() -> AssetBalanceDisplayInfo {
        guard !isRootFlow else {
            return chainAsset.assetDisplayInfo
        }

        if let selectedTarget {
            return selectedTarget.assetDisplayInfo(basedOn: chainAsset.assetDisplayInfo)
        }

        let taoDisplayInfo = chainAsset.assetDisplayInfo

        return AssetBalanceDisplayInfo(
            displayPrecision: taoDisplayInfo.displayPrecision,
            assetPrecision: taoDisplayInfo.assetPrecision,
            symbol: "SN\(flowNetuid)",
            symbolValueSeparator: taoDisplayInfo.symbolValueSeparator,
            symbolPosition: taoDisplayInfo.symbolPosition,
            icon: nil
        )
    }

    func makeInputBalanceViewModelFactory() -> BalanceViewModelFactoryProtocol {
        guard !isRootFlow else {
            return balanceViewModelFactory
        }

        if let cachedInputBalanceViewModelFactory {
            return cachedInputBalanceViewModelFactory
        }

        let factory = BalanceViewModelFactory(
            targetAssetInfo: inputDisplayInfo(),
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        cachedInputBalanceViewModelFactory = factory

        return factory
    }

    func inputPriceData() -> PriceData? {
        isRootFlow ? price : nil
    }

    func stakedAmountInPlank() -> Balance {
        guard let hotkey = getDelegateAccount() else {
            return 0
        }

        return flowPositions().first { $0.hotkey == hotkey }?.stakeAlpha ?? 0
    }

    func availableAmountDecimal() -> Decimal {
        unstakeBasis.available.decimal(assetInfo: inputDisplayInfo())
    }

    func inputAmountInPlank() -> Balance? {
        let inputAmount = inputResult?.absoluteValue(from: availableAmountDecimal()) ?? 0

        let amount = inputAmount.toSubstrateAmount(
            precision: inputDisplayInfo().assetPrecision
        )

        return amount.map { min($0, unstakeBasis.available) }
    }

    func groupExitHotkeys(for amount: Balance?) -> [AccountId]? {
        guard let amount, let positionsState else {
            return nil
        }

        return SubtensorConfirmTapRule.groupExitHotkeys(for: amount, netuid: flowNetuid, in: positionsState)
    }

    func currentSpotPrice() -> Balance? {
        quoteFlow.freshQuote?.quote.spotPrice ?? selectedTarget?.listedPrice
    }

    func currentLimitPrice() -> Balance? {
        selectedTarget?.unstakeLimitPrice(spot: currentSpotPrice(), tolerance: slippage)
    }

    func getUnstakeModel() -> SubtensorUnstakeModel? {
        guard let hotkey = getDelegateAccount(), let amount = inputAmountInPlank() else {
            return nil
        }

        guard isRootFlow || currentLimitPrice() != nil else {
            return nil
        }

        return SubtensorUnstakeModel(
            hotkey: hotkey,
            netuid: flowNetuid,
            amount: amount,
            exitHotkeys: groupExitHotkeys(for: amount)
        )
    }

    func claimablePayout() -> Balance? {
        guard isRootFlow, let hotkey = getDelegateAccount() else {
            return nil
        }

        return claimable?.redeemable(for: hotkey)
    }

    func provideAmountInputViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: availableAmountDecimal())

        let viewModel = makeInputBalanceViewModelFactory().createBalanceInputViewModel(
            inputAmount
        ).value(for: selectedLocale)

        view?.didReceiveAmount(inputViewModel: viewModel)
    }

    func provideAmountInputViewModelIfInputRate() {
        guard case .rate = inputResult else {
            return
        }

        provideAmountInputViewModel()
    }

    func provideAssetViewModel() {
        let availableDecimal = availableAmountDecimal()

        let inputAmount = inputResult?.absoluteValue(from: availableDecimal) ?? 0

        let viewModel = makeInputBalanceViewModelFactory().createAssetBalanceViewModel(
            inputAmount,
            balance: availableDecimal,
            priceData: inputPriceData()
        ).value(for: selectedLocale)

        view?.didReceiveAssetBalance(viewModel: viewModel)
    }

    func provideUnstakeAvailability() {
        quoteView?.didReceiveUnstakeUnavailable(unstakeBasis.isFullyLocked)
    }

    func provideMinStakeViewModel() {
        view?.didReceiveMinStake(viewModel: nil)
    }

    func provideTransferableViewModel() {
        let viewModel: BalanceViewModelProtocol? = balance.map { value in
            let transferableDecimal = value.transferable.decimal(
                assetInfo: chainAsset.assetDisplayInfo
            )

            return balanceViewModelFactory.balanceFromPrice(
                transferableDecimal,
                priceData: price
            ).value(for: selectedLocale)
        }

        view?.didReceiveTransferable(viewModel: viewModel)
    }

    func provideFeeViewModel() {
        guard let fee else {
            view?.didReceiveFee(viewModel: nil)
            return
        }

        let feeDecimal = fee.amount.decimal(assetInfo: chainAsset.assetDisplayInfo)

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            feeDecimal,
            priceData: price
        ).value(for: selectedLocale).approximatelyForSubtensorFee()

        view?.didReceiveFee(viewModel: viewModel)
    }

    func provideDelegateViewModel() {
        if let delegateDisplayAddress {
            let viewModel = accountDetailsViewModelFactory.createCollator(
                from: delegateDisplayAddress,
                stakedAmount: stakedAmountInPlank(),
                // the position is held in alpha on the subnet lane, so the row follows the
                // input denomination rather than the chain asset
                assetDisplayInfo: inputDisplayInfo(),
                locale: selectedLocale
            )

            view?.didReceiveCollator(viewModel: viewModel)
        } else {
            view?.didReceiveCollator(viewModel: nil)
        }
    }

    func provideHints() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        var hints: [String] = []

        let basis = unstakeBasis

        if basis.isFullyLocked {
            hints.append(strings.stakingSubtensorUnstakeNothingAvailableHint())
        } else if basis.locked > 0 {
            let lockedDecimal = basis.locked.decimal(assetInfo: inputDisplayInfo())

            let lockedAmount = makeInputBalanceViewModelFactory().amountFromValue(
                lockedDecimal
            ).value(for: selectedLocale)

            hints.append(strings.stakingSubtensorUnstakeLockedPortionHint(lockedAmount))
        }

        hints.append(strings.stakingSubtensorHintUnstakeInstant())

        if !isRootFlow {
            hints.append(strings.stakingSubtensorHintSimulatedReceive())
        }

        view?.didReceiveHints(viewModel: hints)
    }

    func provideQuoteViewModel() {
        guard let selectedTarget else {
            quoteView?.didReceiveQuote(viewModel: nil)
            return
        }

        let viewModel = quoteViewModelFactory.createQuotePanel(
            for: quoteFlow.freshQuote?.quote,
            target: selectedTarget,
            locale: selectedLocale
        )

        quoteView?.didReceiveQuote(viewModel: viewModel)
    }

    func provideSlippageViewModel() {
        guard !isRootFlow else {
            quoteView?.didReceiveSlippage(viewModel: nil)
            return
        }

        let viewModel = quoteViewModelFactory.createSlippageViewModel(
            for: slippage,
            locale: selectedLocale
        )

        quoteView?.didReceiveSlippage(viewModel: viewModel)
    }

    func quoteRequest() -> SubtensorTradeQuoteRequest? {
        guard
            case let .subnet(info, _) = selectedTarget,
            let amount = inputAmountInPlank(),
            amount > 0 else {
            return nil
        }

        return .sell(netuid: info.netuid, alpha: amount, tolerance: slippage)
    }

    func feeOperation() -> SubtensorStakingOperation? {
        let hotkey = getDelegateAccount() ?? AccountId.zeroAccountId(of: chainAsset.chain.accountIdSize)
        let amount = inputAmountInPlank() ?? 0
        let exitHotkeys = groupExitHotkeys(for: amount)

        guard !isRootFlow else {
            if let exitHotkeys {
                return .rootUnstakeAll(hotkeys: exitHotkeys)
            }

            return .rootUnstake(hotkey: hotkey, amount: amount)
        }

        guard let limitPrice = currentLimitPrice(), let spotPrice = currentSpotPrice() else {
            return nil
        }

        let placeholder = Decimal(1).toSubstrateAmount(precision: inputDisplayInfo().assetPrecision) ?? 1
        let alpha = amount > 0 ? amount : placeholder
        let quotedTaoOut = quoteFlow.freshQuote?.quote.sim.taoAmount ??
            alpha * spotPrice / SubtensorStakingPallet.alphaPriceScale

        guard quotedTaoOut > 0 else {
            return nil
        }

        if let exitHotkeys {
            return .subnetSellAll(
                hotkeys: exitHotkeys,
                netuid: flowNetuid,
                limitPrice: limitPrice,
                quotedTaoOut: quotedTaoOut
            )
        }

        return .subnetSell(
            hotkey: hotkey,
            netuid: flowNetuid,
            alpha: alpha,
            limitPrice: limitPrice,
            quotedTaoOut: quotedTaoOut
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

    func updateQuote() {
        if let request = quoteFlow.updateRequest(quoteRequest()) {
            interactor.refreshQuote(for: request)
        }

        provideQuoteViewModel()
    }

    func forceQuoteRefresh() {
        let request = quoteRequest()

        if quoteFlow.updateRequest(request) != nil {
            provideQuoteViewModel()
        }

        guard let request else {
            return
        }

        interactor.refreshQuote(for: request)
    }

    func setupInitialDelegate() {
        guard delegateDisplayAddress == nil else {
            return
        }

        let optMaxPosition = flowPositions().max { $0.stakeAlpha < $1.stakeAlpha }

        guard
            let position = optMaxPosition,
            let address = try? position.hotkey.toAddress(using: chainAsset.chain.chainFormat) else {
            return
        }

        let name = delegateIdentities?[position.hotkey]?.displayName
        delegateDisplayAddress = DisplayAddress(address: address, username: name ?? "")
    }

    func changeDelegate(with hotkey: AccountId, name: String?) {
        guard
            let newAddress = try? hotkey.toAddress(using: chainAsset.chain.chainFormat),
            newAddress != delegateDisplayAddress?.address else {
            return
        }

        delegateDisplayAddress = DisplayAddress(address: newAddress, username: name ?? "")
        preflight = nil

        provideDelegateViewModel()
        provideAssetViewModel()
        provideAmountInputViewModel()
        provideHints()
        provideUnstakeAvailability()

        interactor.applyDelegate(with: hotkey, netuid: flowNetuid)
        refreshFee()
        updateQuote()
    }

    func updateView() {
        provideAmountInputViewModel()
        provideDelegateViewModel()
        provideAssetViewModel()
        provideMinStakeViewModel()
        provideTransferableViewModel()
        provideHints()
        provideFeeViewModel()
        provideQuoteViewModel()
        provideSlippageViewModel()
        provideUnstakeAvailability()
    }

    func getQuoteContext() -> SubtensorQuoteValidatingContext? {
        guard !isRootFlow else {
            return nil
        }

        let latestQuote = quoteFlow.freshQuote

        return SubtensorQuoteValidatingContext(
            latestQuote: latestQuote,
            acknowledgedLimit: latestQuote?.limitPrice,
            tradesUnavailable: tradesUnavailable,
            onQuoteRefresh: { [weak self] in
                self?.forceQuoteRefresh()
            }
        )
    }
}

extension SubtensorUnstakeSetupPresenter {
    /// closing the position is only on offer while the whole of it is unlocked: with a locked
    /// portion a max input still leaves a remainder, so the offer would re-raise the same warning
    func makeUnstakeAllOffer() -> (() -> Void)? {
        guard unstakeBasis.isFullyAvailable else {
            return nil
        }

        return { [weak self] in
            self?.selectAmountPercentage(1.0)
        }
    }

    func getValidationDependencies() -> SubtensorUnstakeValidatingDep {
        SubtensorUnstakeValidatingDep(
            netuid: flowNetuid,
            accountId: selectedAccount.chainAccount.accountId,
            amount: inputAmountInPlank(),
            positionAlpha: stakedAmountInPlank(),
            availability: preflight?.stakeAvailability,
            exitHotkeys: groupExitHotkeys(for: inputAmountInPlank()),
            balance: balance,
            fee: fee,
            existentialDeposit: existentialDeposit,
            preflight: preflight,
            holds: nil,
            currentBlock: currentBlock,
            blockTime: chainAsset.chain.defaultBlockTimeMillis ?? SubtensorStakingFlowConstants.blockTimeMillis,
            assetDisplayInfo: inputDisplayInfo(),
            syncFailed: positionsSyncFailed,
            onFeeRefresh: { [weak self] in
                self?.refreshFee()
            },
            onPreflightRefresh: { [weak self] in
                guard let self, let hotkey = getDelegateAccount() else {
                    return
                }

                interactor.applyDelegate(with: hotkey, netuid: flowNetuid)
            },
            onPositionsRefresh: { [weak self] in
                self?.interactor.refreshPositions()
            },
            onUnstakeAll: makeUnstakeAllOffer(),
            quoteContext: getQuoteContext()
        )
    }
}

extension SubtensorUnstakeSetupPresenter: SubtensorUnstakeSetupPresenterProtocol {
    func setup() {
        setupInitialDelegate()

        updateView()

        interactor.setup()

        if let hotkey = getDelegateAccount() {
            interactor.applyDelegate(with: hotkey, netuid: flowNetuid)
        }

        refreshFee()
    }

    func selectCollator() {
        let positions = flowPositions()

        guard !positions.isEmpty else {
            return
        }

        let stakedDelegates = positions.map { position in
            CollatorStakingAccountViewModelFactory.StakedCollator(
                collator: position.hotkey,
                amount: position.stakeAlpha
            )
        }.sorted { $0.amount > $1.amount }

        let viewModels = accountDetailsViewModelFactory.createViewModels(
            from: stakedDelegates,
            identities: delegateIdentities,
            disabled: [],
            assetDisplayInfo: inputDisplayInfo()
        )

        let selectedDelegate = getDelegateAccount()

        let selectedIndex = stakedDelegates.firstIndex { $0.collator == selectedDelegate } ?? NSNotFound

        wireframe.showUndelegationSelection(
            from: view,
            viewModels: viewModels,
            selectedIndex: selectedIndex,
            delegate: self,
            context: stakedDelegates as NSArray,
            statics: .subtensorValidator
        )
    }

    func selectSlippage() {
        wireframe.showSlippageEdit(from: view, current: slippage) { [weak self] newValue in
            guard let self else {
                return
            }

            slippage = newValue

            provideSlippageViewModel()
            refreshFee()
        }
    }

    func updateAmount(_ newValue: Decimal?) {
        inputResult = newValue.map { .absolute($0) }

        refreshFee()
        updateQuote()
        provideAssetViewModel()
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))

        provideAmountInputViewModel()

        refreshFee()
        updateQuote()
        provideAssetViewModel()
    }

    func proceed() {
        validateUnstake(
            for: getValidationDependencies(),
            dataValidationFactory: dataValidationFactory,
            selectedLocale: selectedLocale
        ) { [weak self] in
            guard
                let self,
                let unstakeModel = getUnstakeModel(),
                let delegate = delegateDisplayAddress else {
                return
            }

            wireframe.showConfirm(
                from: view,
                model: SubtensorUnstakeConfirmModel(
                    origin: isRootFlow ? .unstake : .sell,
                    account: selectedAccount,
                    target: selectedTarget ?? .root,
                    validator: SubtensorConfirmValidator(
                        hotkey: unstakeModel.hotkey,
                        display: delegate,
                        annualRate: nil
                    ),
                    unstakeModel: unstakeModel,
                    tolerance: isRootFlow ? nil : slippage,
                    acknowledgedQuote: isRootFlow ? nil : quoteFlow.freshQuote
                )
            )
        }
    }
}

extension SubtensorUnstakeSetupPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let delegates = context as? [CollatorStakingAccountViewModelFactory.StakedCollator] else {
            return
        }

        let hotkey = delegates[index].collator

        changeDelegate(with: hotkey, name: delegateIdentities?[hotkey]?.displayName)
    }
}

extension SubtensorUnstakeSetupPresenter: SubtensorUnstakePresenterValidating {}

extension SubtensorUnstakeSetupPresenter: SubtensorUnstakeSetupInteractorOutputProtocol {
    func didReceiveSubnetsInfo(_ info: SubtensorSubnetsInfo) {
        logger.debug("Subnets info received")

        guard
            !isRootFlow,
            let subnetInfo = info.subnets.first(where: { $0.netuid == flowNetuid }),
            let subnetPrice = info.prices[flowNetuid] else {
            return
        }

        selectedTarget = .subnet(info: subnetInfo, price: subnetPrice)
        cachedInputBalanceViewModelFactory = nil

        provideAmountInputViewModel()
        provideAssetViewModel()
        provideSlippageViewModel()
        // the alpha symbol only becomes known here, and the locked-portion hint carries it
        provideHints()

        updateQuote()
        refreshFee()
    }

    func didReceiveSubnetsInfoError(_ error: Error) {
        logger.error("Subnets info failed: \(error)")

        guard !isRootFlow else {
            return
        }

        wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
            self?.interactor.retrySubnetsInfo()
        }
    }

    func didReceivePositionsSyncFailed(_ isFailed: Bool) {
        logger.debug("Positions sync failed: \(isFailed)")

        positionsSyncFailed = isFailed
    }

    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        logger.debug("Balance: \(String(describing: balance))")

        self.balance = balance

        provideTransferableViewModel()
    }

    func didReceivePrice(_ priceData: PriceData?) {
        logger.debug("Price: \(String(describing: priceData))")

        price = priceData

        provideAssetViewModel()
        provideTransferableViewModel()
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

        let shouldSetupInitialDelegate = delegateDisplayAddress == nil

        if shouldSetupInitialDelegate {
            setupInitialDelegate()

            if let hotkey = getDelegateAccount() {
                interactor.applyDelegate(with: hotkey, netuid: flowNetuid)
            }
        }

        provideDelegateViewModel()
        provideAssetViewModel()
        provideAmountInputViewModelIfInputRate()
        provideHints()
        provideUnstakeAvailability()

        refreshFee()
        updateQuote()
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

        provideQuoteViewModel()
    }

    func didReceivePreflight(_ preflight: SubtensorStakingPreflight) {
        logger.debug("Preflight: \(preflight)")

        // availability arrives after first paint and again on every delegate change, so the
        // input basis has to re-derive the same way it does when positions land
        let availabilityChanged = self.preflight?.stakeAvailability != preflight.stakeAvailability

        self.preflight = preflight

        guard availabilityChanged else {
            return
        }

        provideAssetViewModel()
        provideAmountInputViewModelIfInputRate()
        provideHints()
        provideUnstakeAvailability()

        refreshFee()
        updateQuote()
    }

    func didReceiveExistentialDeposit(_ deposit: Balance) {
        logger.debug("Existential deposit: \(deposit)")

        existentialDeposit = deposit
    }

    func didReceiveDelegateIdentities(_ identities: [AccountId: AccountIdentity]?) {
        logger.debug("Did receive delegate identities")

        delegateIdentities = identities

        if
            let delegateAddress = delegateDisplayAddress?.address,
            let hotkey = getDelegateAccount(),
            let displayName = identities?[hotkey]?.displayName {
            delegateDisplayAddress = DisplayAddress(address: delegateAddress, username: displayName)
        }

        provideDelegateViewModel()
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
                guard let self, let hotkey = getDelegateAccount() else {
                    return
                }

                interactor.applyDelegate(with: hotkey, netuid: flowNetuid)
            }
        case .quoteFailed:
            quoteFlow.clearQuote()
            provideQuoteViewModel()
        }
    }
}

extension SubtensorUnstakeSetupPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
