import BigInt
import Foundation
import Foundation_iOS

final class SubtensorUnstakeSetupPresenter {
    weak var view: SubtensorUnstakeSetupViewProtocol?
    let wireframe: SubtensorStakeSetupWireframeProtocol
    let interactor: SubtensorUnstakeSetupInteractorInputProtocol
    let logger: LoggerProtocol

    let netuid: UInt16
    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let slippage: BigRational
    let viewModelFactory: SubtensorUnstakeSetupViewModelFactory
    let dataValidationFactory: SubtensorValidationFactoryProtocol

    var target: SubtensorStakeTarget?
    var positionsState: Multistaking.SubtensorState?
    var group: SubtensorPortfolioGroup?
    var isPositionsSyncFailed = false
    var inputResult: AmountInputResult?
    var balance: AssetBalance?
    var price: PriceData?
    var fee: ExtrinsicFeeProtocol?
    var preflight: SubtensorPreflight?
    var blockTime: BlockTime?
    var existentialDeposit: Balance?
    var currentBlock: BlockNumber?
    var catalogue: SubtensorSubnetCatalogue?
    var subnetLogos: SubtensorSubnetLogos?
    var isSubnetsRefreshForced = false
    var validatorRequest: AccountId?
    var failedValidatorRequest: AccountId?
    var validatorItems: [AccountId: SubtensorValidatorDirectoryItem] = [:]
    var validatorsRequest: [AccountId]?
    var validatorsResolved: [AccountId]?
    weak var validatorPicker: CollatorStakingTargetPicker?
    var selection: SubtensorUnstakeSelection?
    var preflightRequest: AccountId?
    var holds: [AccountId: SubtensorRootHold]?
    var groupHotkeys: [AccountId: SubtensorGroupHotkeyInfo]?
    var quoteFlow = SubtensorQuoteFlowModel()
    var latestQuote: SubtensorTradeQuote?
    var acceptedQuote: SubtensorTradeQuote?
    var isQuoteFailed = false
    var tradesUnavailable = false
    var costBasis: SubtensorCostBasisState = .loading
    var novaFeeRate: BigRational?
    var isConfirmationShown = false
    var isBlockedTracked = false
    let dataAnalytics = SubtensorDataAnalytics(screen: .unstakeSetup)

    private var feeShape: FeeShape?

    init(
        interactor: SubtensorUnstakeSetupInteractorInputProtocol,
        wireframe: SubtensorStakeSetupWireframeProtocol,
        netuid: UInt16,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        slippage: BigRational,
        dataValidationFactory: SubtensorValidationFactoryProtocol,
        viewModelFactory: SubtensorUnstakeSetupViewModelFactory,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.netuid = netuid
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.slippage = slippage
        self.dataValidationFactory = dataValidationFactory
        self.viewModelFactory = viewModelFactory
        self.logger = logger

        if netuid == SubtensorPallet.rootNetuid {
            target = .root
        }

        self.localizationManager = localizationManager
    }
}

private extension SubtensorUnstakeSetupPresenter {
    struct FeeShape: Equatable {
        let exits: [AccountId]
        let partials: [AccountId]

        init(plan: SubtensorUnstakePlan) {
            exits = plan.exits.map(\.hotkey)
            partials = plan.partials.map(\.hotkey)
        }
    }

    func feeOperation(for plan: SubtensorUnstakePlan) -> SubtensorOperation? {
        guard !isRoot else {
            return plan.rootOperation(amount: plan.amount)
        }

        guard let limitPrice = currentLimitPrice(), let spotPrice = currentSpotPrice() else {
            return nil
        }

        let quotedTaoOut = quoteFlow.freshQuote?.quote.sim.taoAmount ??
            plan.amount * spotPrice / SubtensorPallet.alphaPriceScale

        guard quotedTaoOut > 0 else {
            return nil
        }

        return plan.subnetOperation(netuid: netuid, limitPrice: limitPrice, quotedTaoOut: quotedTaoOut, novaFee: nil)
    }
}

extension SubtensorUnstakeSetupPresenter {
    var isRoot: Bool {
        netuid == SubtensorPallet.rootNetuid
    }

    func unstakeFloors() -> SubtensorUnstakeFloors {
        guard let preflight, let price = isRoot ? SubtensorPallet.alphaPriceScale : currentLimitPrice() else {
            return .none
        }

        return SubtensorUnstakeFloors(
            yield: SubtensorGroupUnstakeBasis.floorAlpha(
                minTao: preflight.minStake,
                price: price,
                feeRate: isRoot ? 0 : latestQuote?.quote.feeRate ?? 0
            ),
            sweep: SubtensorGroupUnstakeBasis.floorAlpha(
                minTao: preflight.effectiveNominatorMinStake,
                price: price,
                feeRate: 0
            )
        )
    }

    var basis: SubtensorGroupUnstakeBasis? {
        if let group, let currentSelection {
            return SubtensorGroupUnstakeBasis.make(
                from: group,
                selection: currentSelection,
                excluding: heldHotkeys,
                groupHotkeys: groupHotkeys ?? [:],
                floor: unstakeFloors().yield,
                coldkey: selectedAccount.chainAccount.accountId
            )
        }

        guard positionsState != nil else {
            return nil
        }

        return SubtensorGroupUnstakeBasis(total: 0, available: 0, positions: [])
    }

    var maxAmount: Balance? {
        basis?.max(floor: unstakeFloors().yield)
    }

    var inputDisplayInfo: AssetBalanceDisplayInfo {
        viewModelFactory.inputDisplayInfo(for: netuid, catalogue: catalogue)
    }

    var subnetRef: SubtensorSubnetRef? {
        target?.subnetRef
    }

    func requestedAmount() -> Balance? {
        switch inputResult {
        case let .rate(rate):
            guard let maxAmount else {
                return nil
            }

            guard rate < 1 else {
                return maxAmount
            }

            return BigRational.fraction(from: rate)?.mul(value: maxAmount)
        case let .absolute(value):
            return value.toSubstrateAmount(precision: inputDisplayInfo.assetPrecision)
        case .none:
            return nil
        }
    }

    func inputAmount() -> Balance? {
        guard let requested = requestedAmount() else {
            return nil
        }

        return plan(for: requested)?.amount ?? requested
    }

    func plan(for amount: Balance) -> SubtensorUnstakePlan? {
        basis?.plan(for: amount, floors: unstakeFloors())
    }

    func feePlan() -> SubtensorUnstakePlan? {
        guard let anchorHotkey else {
            return nil
        }

        let amount = inputAmountOrPlaceholder()

        return plan(for: amount) ?? SubtensorUnstakePlan(
            exits: [],
            partials: [SubtensorUnstakeSlice(hotkey: anchorHotkey, alpha: amount)]
        )
    }

    func loadGroupHotkeys() {
        guard let group else {
            return
        }

        interactor.loadGroupHotkeys(group.positions.map(\.hotkey), netuid: netuid)
    }

    func holdRemainingBlocks(for amount: Balance?) -> UInt64? {
        let held = heldHotkeys

        guard !held.isEmpty, let group, let maxAmount, let holds, let currentBlock else {
            return nil
        }

        if let hotkey = currentSelection?.hotkey {
            return held.contains(hotkey) ? holds[hotkey]?.remainingBlocks(at: UInt64(currentBlock)) : nil
        }

        guard held.count == group.positions.count || (amount ?? 0) > maxAmount else {
            return nil
        }

        return held.compactMap { holds[$0]?.remainingBlocks(at: UInt64(currentBlock)) }.max()
    }

    func currentSpotPrice() -> Balance? {
        latestQuote?.quote.spotPrice ?? target?.listedPrice
    }

    func currentLimitPrice() -> Balance? {
        target?.unstakeLimitPrice(spot: currentSpotPrice(), tolerance: slippage)
    }

    func refreshFee() {
        guard let plan = feePlan(), let operation = feeOperation(for: plan) else {
            return
        }

        let newShape = FeeShape(plan: plan)

        if newShape != feeShape {
            feeShape = newShape
            fee = nil
        }

        interactor.estimateFee(for: operation)
    }

    func quoteRequest() -> SubtensorTradeQuoteRequest? {
        guard !isRoot, target != nil else {
            return nil
        }

        return .sell(netuid: netuid, alpha: inputAmountOrPlaceholder(), tolerance: slippage)
    }

    func refreshPreflight() {
        guard let anchorHotkey else {
            return
        }

        preflightRequest = anchorHotkey
        interactor.refreshPreflight(for: anchorHotkey, netuid: netuid)
    }

    func applyInputChange() {
        refreshFee()
        updateQuote()
        provideViewModel()
    }

    func applyPlanChange(from previousPlan: SubtensorUnstakePlan?) {
        reconcileAnchor()

        let plan = feePlan()

        guard plan != previousPlan else {
            return
        }

        if case .rate = inputResult, plan?.amount != previousPlan?.amount {
            provideAmountInputViewModel()
        }

        refreshFee()
        updateQuote()
    }

    func didReceiveQuote(_ quote: SubtensorTradeQuote) {
        let previousPlan = feePlan()

        latestQuote = quote

        if quoteFlow.applyQuote(quote) {
            tradesUnavailable = false
            isQuoteFailed = false
        }

        applyPlanChange(from: previousPlan)
        provideViewModel()
    }

    func provideAmountInputViewModel() {
        let decimal = inputAmount()?.decimal(assetInfo: inputDisplayInfo)

        let viewModel = viewModelFactory.balanceViewModelFactory.createBalanceInputViewModel(decimal).value(
            for: selectedLocale
        )

        view?.didReceiveAmount(inputViewModel: viewModel)
    }

    func provideAssetViewModel() {
        let viewModel = viewModelFactory.createAssetViewModel(
            for: netuid,
            catalogue: catalogue,
            subnetLogos: subnetLogos,
            locale: selectedLocale
        )

        view?.didReceiveAmountAsset(viewModel: viewModel)
    }

    func provideViewModel() {
        let amount = inputAmount()

        let input = SubtensorUnstakeSetupViewModelInput(
            netuid: netuid,
            target: target,
            catalogue: catalogue,
            basis: basis,
            maxAmount: maxAmount,
            amount: amount,
            validatorHotkey: anchorHotkey,
            validatorName: anchorHotkey.flatMap { validatorName(for: $0) },
            isValidatorSelectable: (group?.positions.count ?? 0) > 1,
            isAllValidators: currentSelection == .all,
            legCap: isLegCapped ? SubtensorGroupUnstakeBasis.maxLegs : nil,
            fee: fee,
            price: price,
            quote: quoteFlow.freshQuote,
            isQuoteFailed: isQuoteFailed,
            holdRemainingBlocks: holdRemainingBlocks(for: amount),
            blockTime: blockTime,
            costBasis: costBasis
        )

        view?.didReceive(viewModel: viewModelFactory.createViewModel(for: input, locale: selectedLocale))
        trackBlockedIfNeeded()
    }
}

extension SubtensorUnstakeSetupPresenter: SubtensorQuoteHandling {
    var retryView: ControllerBackedProtocol? { view }
    var retryWireframe: AlertPresentable & FeeRetryable & CommonRetryable { wireframe }
    var quoteInteractor: SubtensorBaseInteractorInputProtocol { interactor }
    var loadingView: LoadableViewProtocol? { view }
    var alphaDisplayInfo: AssetBalanceDisplayInfo { inputDisplayInfo }
}
