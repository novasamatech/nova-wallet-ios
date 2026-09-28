import BigInt
import Foundation
import Foundation_iOS

final class SubtensorStakingSetupPresenter {
    weak var view: SubtensorStakingSetupViewProtocol?
    let wireframe: SubtensorStakingSetupWireframeProtocol
    let interactor: SubtensorStakingSetupInteractorInputProtocol
    let logger: LoggerProtocol

    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let accountDetailsViewModelFactory: CollatorStakingAccountViewModelFactoryProtocol
    let quoteViewModelFactory: SubtensorQuoteViewModelFactoryProtocol
    let dataValidationFactory: SubtensorStakingValidationFactoryProtocol

    private(set) var inputResult: AmountInputResult?
    private(set) var fee: ExtrinsicFeeProtocol?
    private(set) var balance: AssetBalance?
    private(set) var price: PriceData?
    private(set) var positionsState: Multistaking.SubtensorStakingState?
    private(set) var preflight: SubtensorStakingPreflight?
    private(set) var existentialDeposit: Balance?
    private(set) var delegateDisplayAddress: DisplayAddress?
    private(set) var delegateTake: UInt16?
    private(set) var delegateIdentities: [AccountId: AccountIdentity]?
    private(set) var currentBlock: BlockNumber?

    private(set) var selectedTarget: SubtensorStakeTarget = .root
    private(set) var slippage: BigRational = SubtensorSlippageTolerance.defaultTolerance
    private(set) var quoteFlow = SubtensorQuoteFlowModel()
    private(set) var rewardEngine: SubtensorRewardCalculatorEngineProtocol?
    private var hasAcknowledgedSubnetRisk = false
    private let initialNetuid: UInt16?
    private var targetReady: Bool

    private lazy var aprFormatter = NumberFormatter.positivePercentAPR.localizableResource()

    init(
        interactor: SubtensorStakingSetupInteractorInputProtocol,
        wireframe: SubtensorStakingSetupWireframeProtocol,
        chainAsset: ChainAsset,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        accountDetailsViewModelFactory: CollatorStakingAccountViewModelFactoryProtocol,
        quoteViewModelFactory: SubtensorQuoteViewModelFactoryProtocol,
        initialPosition: SubtensorStakingPosition?,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.dataValidationFactory = dataValidationFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.accountDetailsViewModelFactory = accountDetailsViewModelFactory
        self.quoteViewModelFactory = quoteViewModelFactory
        self.logger = logger
        initialNetuid = initialPosition?.netuid
        targetReady = initialPosition?.netuid == nil || initialPosition?.netuid == SubtensorStakingPallet.rootNetuid

        if
            let initialPosition,
            let address = try? initialPosition.hotkey.toAddress(using: chainAsset.chain.chainFormat) {
            delegateDisplayAddress = DisplayAddress(address: address, username: "")
        }

        self.localizationManager = localizationManager
    }
}

private extension SubtensorStakingSetupPresenter {
    func showValidatorSelection() {
        wireframe.showValidatorSelection(from: view, target: selectedTarget, delegate: self)
    }

    func getDelegateAccount() -> AccountId? {
        try? delegateDisplayAddress?.address.toAccountId(using: chainAsset.chain.chainFormat)
    }

    func targetPositions() -> [SubtensorStakingPosition] {
        (positionsState?.positions ?? []).filter { $0.netuid == selectedTarget.netuid }
    }

    func existingStakeInPlank() -> Balance? {
        guard let hotkey = getDelegateAccount() else {
            return nil
        }

        return targetPositions().first { $0.hotkey == hotkey }?.stakeAlpha
    }

    /// an existing position on the selected target is held in alpha whenever that target is a
    /// subnet, so it must never be labelled with the chain asset ticker
    func existingStakeDisplayInfo() -> AssetBalanceDisplayInfo {
        selectedTarget.assetDisplayInfo(basedOn: chainAsset.assetDisplayInfo)
    }

    func balanceMinusFee() -> Decimal {
        let balanceValue = balance?.transferable ?? 0
        let feeValue = fee?.amountForCurrentAccount ?? 0

        return Decimal.fromSubstrateAmount(
            balanceValue.subtractOrZero(feeValue),
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) ?? 0
    }

    func inputAmountInPlank() -> Balance? {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0

        return inputAmount.toSubstrateAmount(
            precision: chainAsset.assetDisplayInfo.assetPrecision
        )
    }

    func currentSpotPrice() -> Balance? {
        quoteFlow.freshQuote?.spotPrice ?? selectedTarget.listedPrice
    }

    func currentLimitPrice() -> Balance? {
        selectedTarget.stakeLimitPrice(spot: currentSpotPrice(), tolerance: slippage)
    }

    func getStakeModel() -> SubtensorStakeModel? {
        guard
            let hotkey = getDelegateAccount(),
            let amount = inputAmountInPlank() else {
            return nil
        }

        let limitPrice = currentLimitPrice()

        guard selectedTarget.isRoot || limitPrice != nil else {
            return nil
        }

        return SubtensorStakeModel(
            hotkey: hotkey,
            netuid: selectedTarget.netuid,
            amount: amount,
            limitPrice: limitPrice
        )
    }

    func provideAmountInputViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee())

        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(
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
        let balanceDecimal = (balance?.transferable ?? 0).decimal(
            assetInfo: chainAsset.assetDisplayInfo
        )

        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0

        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: balanceDecimal,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAssetBalance(viewModel: viewModel)
    }

    func provideMinStakeViewModel() {
        guard let minStakeDecimal = preflight?.minStake.decimal(
            assetInfo: chainAsset.assetDisplayInfo
        ) else {
            view?.didReceiveMinStake(viewModel: nil)
            return
        }

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            minStakeDecimal,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveMinStake(viewModel: viewModel)
    }

    func provideFeeViewModel() {
        guard let feeDecimal = fee?.amount.decimal(assetInfo: chainAsset.assetDisplayInfo) else {
            view?.didReceiveFee(viewModel: nil)
            return
        }

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
                stakedAmount: existingStakeInPlank(),
                assetDisplayInfo: existingStakeDisplayInfo(),
                locale: selectedLocale
            )

            view?.didReceiveCollator(viewModel: viewModel)
        } else {
            view?.didReceiveCollator(viewModel: nil)
        }
    }

    func provideStakeTargetViewModel() {
        let viewModel = quoteViewModelFactory.createTargetViewModel(
            for: selectedTarget,
            locale: selectedLocale
        )

        view?.didReceiveStakeTarget(viewModel: viewModel)
    }

    func provideQuoteViewModel() {
        let viewModel = quoteViewModelFactory.createQuotePanel(
            for: quoteFlow.freshQuote,
            target: selectedTarget,
            locale: selectedLocale
        )

        view?.didReceiveQuote(viewModel: viewModel)
    }

    /// spec §6.3 — a TAO-denominated earn headline is honest only on the root lane, where both the
    /// principal and the yield are TAO; the subnet lane keeps its α-APR inside the picker instead.
    ///
    /// spec §6.2 — the rate is netted by the picked delegate's take, so the row stays hidden while
    /// no take is known rather than falling back to the gross network average
    func provideRewardsViewModel() {
        guard
            selectedTarget.isRoot,
            let take = delegateTake ?? preflight?.delegateTake,
            let annualReturn = rewardEngine?.rootAnnualReturn(take: take) else {
            view?.didReceiveRewardHidden(true)
            return
        }

        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0
        let existingStake = (existingStakeInPlank() ?? 0).decimal(assetInfo: chainAsset.assetDisplayInfo)

        let rewardAmount = (inputAmount + existingStake) * annualReturn

        let balanceViewModel = balanceViewModelFactory.balanceFromPrice(
            rewardAmount,
            priceData: price ?? PriceData.zero()
        ).value(for: selectedLocale)

        let aprString = aprFormatter.value(for: selectedLocale).stringFromDecimal(annualReturn)

        view?.didReceiveReward(
            viewModel: StakingRewardInfoViewModel(
                amountViewModel: balanceViewModel,
                returnPercentage: aprString ?? ""
            )
        )

        view?.didReceiveRewardHidden(false)
    }

    func provideSlippageViewModel() {
        guard !selectedTarget.isRoot else {
            view?.didReceiveSlippage(viewModel: nil)
            return
        }

        let viewModel = quoteViewModelFactory.createSlippageViewModel(
            for: slippage,
            locale: selectedLocale
        )

        view?.didReceiveSlippage(viewModel: viewModel)
    }

    func refreshFee() {
        fee = nil
        provideFeeViewModel()

        let hotkey = getDelegateAccount() ?? AccountId.zeroAccountId(
            of: chainAsset.chain.accountIdSize
        )

        let model = SubtensorStakeModel(
            hotkey: hotkey,
            netuid: selectedTarget.netuid,
            amount: inputAmountInPlank() ?? 0,
            limitPrice: currentLimitPrice()
        )

        interactor.estimateFee(for: .stake(model))
    }

    func updateQuote() {
        let args = SubtensorQuoteFlowModel.stakeArgs(
            for: selectedTarget,
            amount: inputAmountInPlank()
        )

        if let refreshArgs = quoteFlow.updateArgs(args) {
            interactor.refreshQuote(for: refreshArgs)
        }

        provideQuoteViewModel()
    }

    func updateQuoteIfInputRate() {
        guard case .rate = inputResult else {
            return
        }

        updateQuote()
    }

    /// a forced refresh re-derives the args from the current state instead of replaying
    /// a stored snapshot, so a fee or balance change can never pin the quote to stale args
    func forceQuoteRefresh() {
        let args = SubtensorQuoteFlowModel.stakeArgs(
            for: selectedTarget,
            amount: inputAmountInPlank()
        )

        if quoteFlow.updateArgs(args) != nil {
            provideQuoteViewModel()
        }

        guard let args else {
            return
        }

        interactor.refreshQuote(for: args)
    }

    func changeDelegate(with accountId: AccountId, name: String?, take: UInt16?) {
        guard let newAddress = try? accountId.toAddress(using: chainAsset.chain.chainFormat) else {
            return
        }

        if newAddress == delegateDisplayAddress?.address, take == delegateTake { return }

        delegateDisplayAddress = DisplayAddress(address: newAddress, username: name ?? "")
        delegateTake = take
        preflight = nil

        provideDelegateViewModel()
        provideMinStakeViewModel()
        provideRewardsViewModel()

        interactor.applyDelegate(with: accountId, netuid: selectedTarget.netuid)
        refreshFee()
    }

    func applyStakeTarget(_ target: SubtensorStakeTarget) {
        targetReady = true
        view?.didReceiveTargetLoading(false)
        guard target.netuid != selectedTarget.netuid else {
            return
        }

        selectedTarget = target
        preflight = nil

        provideStakeTargetViewModel()
        provideDelegateViewModel()
        provideMinStakeViewModel()
        provideSlippageViewModel()
        provideRewardsViewModel()

        if let hotkey = getDelegateAccount() {
            interactor.applyDelegate(with: hotkey, netuid: target.netuid)
        }

        updateQuote()
        refreshFee()
    }

    func getQuoteContext() -> SubtensorQuoteValidatingContext? {
        guard !selectedTarget.isRoot else {
            return nil
        }

        return SubtensorQuoteValidatingContext(
            args: SubtensorQuoteFlowModel.stakeArgs(
                for: selectedTarget,
                amount: inputAmountInPlank()
            ),
            quote: quoteFlow.freshQuote,
            limitPrice: currentLimitPrice(),
            onQuoteRefresh: { [weak self] in
                self?.forceQuoteRefresh()
            }
        )
    }

    func getValidationDependencies() -> SubtensorStakeValidatingDep {
        SubtensorStakeValidatingDep(
            amount: inputAmountInPlank(),
            balance: balance,
            fee: fee,
            existentialDeposit: existentialDeposit,
            preflight: preflight,
            netuid: selectedTarget.netuid,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            onFeeRefresh: { [weak self] in
                self?.refreshFee()
            },
            onPreflightRefresh: { [weak self] in
                guard let self, let hotkey = getDelegateAccount() else {
                    return
                }

                interactor.applyDelegate(with: hotkey, netuid: selectedTarget.netuid)
            },
            quoteContext: getQuoteContext()
        )
    }
}

extension SubtensorStakingSetupPresenter: SubtensorStakingSetupPresenterProtocol {
    func setup() {
        view?.didReceiveTargetLoading(!targetReady)
        provideAmountInputViewModel()
        provideDelegateViewModel()
        provideAssetViewModel()
        provideMinStakeViewModel()
        provideFeeViewModel()
        provideStakeTargetViewModel()
        provideSlippageViewModel()
        provideQuoteViewModel()
        provideRewardsViewModel()

        interactor.setup()

        if let hotkey = getDelegateAccount() {
            interactor.applyDelegate(with: hotkey, netuid: selectedTarget.netuid)
        }

        refreshFee()
    }

    func selectCollator() {
        let positions = targetPositions()

        guard !positions.isEmpty else {
            showValidatorSelection()
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
            assetDisplayInfo: existingStakeDisplayInfo()
        )

        let selectedDelegate = getDelegateAccount()

        let selectedIndex = stakedDelegates.firstIndex { $0.collator == selectedDelegate } ?? NSNotFound

        wireframe.showDelegationSelection(
            from: view,
            viewModels: viewModels,
            selectedIndex: selectedIndex,
            delegate: self,
            context: stakedDelegates as NSArray,
            statics: .subtensorValidator
        )
    }

    func selectStakeTarget() {
        let selectedTake = delegateTake ?? preflight?.delegateTake

        if hasAcknowledgedSubnetRisk || !selectedTarget.isRoot {
            wireframe.showSubnetSelection(from: view, delegate: self, delegateTake: selectedTake)
        } else {
            wireframe.showSubnetRiskNote(from: view) { [weak self] in
                guard let self else {
                    return
                }

                hasAcknowledgedSubnetRisk = true

                wireframe.showSubnetSelection(from: view, delegate: self, delegateTake: selectedTake)
            }
        }
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
        provideRewardsViewModel()
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))

        provideAmountInputViewModel()

        refreshFee()
        updateQuote()
        provideAssetViewModel()
        provideRewardsViewModel()
    }

    func proceed() {
        guard targetReady else { return }
        let dependencies = getValidationDependencies()

        validateStake(
            for: dependencies,
            dataValidationFactory: dataValidationFactory,
            selectedLocale: selectedLocale
        ) { [weak self] in
            guard
                let self,
                let stakeModel = getStakeModel(),
                let delegate = delegateDisplayAddress else {
                return
            }

            wireframe.showConfirmation(
                from: view,
                model: SubtensorStakingConfirmModel(
                    delegate: delegate,
                    delegateTake: delegateTake ?? preflight?.delegateTake,
                    stakeModel: stakeModel,
                    isStakeMore: existingStakeInPlank() != nil,
                    target: selectedTarget,
                    slippage: selectedTarget.isRoot ? nil : slippage,
                    quote: quoteFlow.freshQuote
                )
            )
        }
    }
}

extension SubtensorStakingSetupPresenter: SubtensorSubnetSelectDelegate {
    func didSelectStakeTarget(_ target: SubtensorStakeTarget) {
        applyStakeTarget(target)
    }

    func didSelectValidator(_ validator: SubtensorValidatorDirectoryItem, for target: SubtensorStakeTarget) {
        applyStakeTarget(target)
        let take = validator.take.map {
            UInt16(clamping: NSDecimalNumber(decimal: $0 * Decimal(SubtensorStakingPallet.perU16Denominator)).intValue)
        }
        changeDelegate(with: validator.hotkey, name: validator.name, take: take)
    }
}

extension SubtensorStakingSetupPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let delegates = context as? [CollatorStakingAccountViewModelFactory.StakedCollator] else {
            return
        }

        let hotkey = delegates[index].collator

        changeDelegate(
            with: hotkey,
            name: delegateIdentities?[hotkey]?.displayName,
            take: nil
        )
    }

    func modalPickerDidSelectAction(context _: AnyObject?) {
        showValidatorSelection()
    }
}

extension SubtensorStakingSetupPresenter: SubtensorStakePresenterValidating {}

extension SubtensorStakingSetupPresenter: SubtensorStakingSetupInteractorOutputProtocol {
    func didReceiveInitialSubnets(_ info: SubtensorSubnetsInfo) {
        guard let initialNetuid,
              let subnet = info.subnets.first(where: { $0.netuid == initialNetuid }),
              let price = info.prices[initialNetuid] else {
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryInitialSubnet()
            }
            return
        }

        applyStakeTarget(.subnet(info: subnet, price: price))
    }

    func didFailInitialSubnets(_ error: Error) {
        logger.error("Initial subnet load failed: \(error)")
        wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
            self?.interactor.retryInitialSubnet()
        }
    }

    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        logger.debug("Balance: \(String(describing: balance))")

        self.balance = balance

        provideAssetViewModel()
        provideAmountInputViewModelIfInputRate()
        updateQuoteIfInputRate()
        provideRewardsViewModel()
    }

    func didReceivePrice(_ priceData: PriceData?) {
        logger.debug("Price: \(String(describing: priceData))")

        price = priceData

        provideAssetViewModel()
        provideMinStakeViewModel()
        provideFeeViewModel()
        provideRewardsViewModel()
    }

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        logger.debug("Fee: \(fee)")

        self.fee = fee

        provideFeeViewModel()
        provideAmountInputViewModelIfInputRate()
        updateQuoteIfInputRate()
        provideRewardsViewModel()
    }

    func didReceivePositions(_ state: Multistaking.SubtensorStakingState?) {
        logger.debug("Positions: \(String(describing: state))")

        positionsState = state

        provideDelegateViewModel()
        provideAssetViewModel()
        provideAmountInputViewModelIfInputRate()
        provideRewardsViewModel()
    }

    func didReceiveClaimable(_ claimable: SubtensorRootClaimable?) {
        logger.debug("Claimable: \(String(describing: claimable))")
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

        provideMinStakeViewModel()
        provideRewardsViewModel()
    }

    func didReceiveRewardEngine(_ engine: SubtensorRewardCalculatorEngineProtocol?) {
        logger.debug("Reward engine received: \(engine != nil)")

        rewardEngine = engine

        provideRewardsViewModel()
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

                interactor.applyDelegate(with: hotkey, netuid: selectedTarget.netuid)
            }
        case .quoteFailed:
            quoteFlow.clearQuote()
            provideQuoteViewModel()
        }
    }
}

extension SubtensorStakingSetupPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideAssetViewModel()
            provideAmountInputViewModel()
            provideMinStakeViewModel()
            provideFeeViewModel()
            provideDelegateViewModel()
            provideStakeTargetViewModel()
            provideSlippageViewModel()
            provideQuoteViewModel()
            provideRewardsViewModel()
        }
    }
}
