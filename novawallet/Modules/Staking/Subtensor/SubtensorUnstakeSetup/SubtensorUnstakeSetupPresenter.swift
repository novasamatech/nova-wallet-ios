import BigInt
import Foundation
import Foundation_iOS

final class SubtensorUnstakeSetupPresenter {
    weak var view: SubtensorUnstakeSetupViewProtocol?
    let wireframe: SubtensorStakingSetupWireframeProtocol
    let interactor: SubtensorUnstakeInteractorInputProtocol
    let logger: LoggerProtocol

    let netuid: UInt16
    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let slippage: BigRational
    let viewModelFactory: SubtensorUnstakeSetupViewModelFactory
    let dataValidationFactory: SubtensorStakingValidationFactoryProtocol

    var target: SubtensorStakeTarget?
    var positionsState: Multistaking.SubtensorStakingState?
    var group: SubtensorPortfolioGroup?
    var isPositionsSyncFailed = false
    var inputResult: AmountInputResult?
    var balance: AssetBalance?
    var price: PriceData?
    var fee: ExtrinsicFeeProtocol?
    var preflight: SubtensorStakingPreflight?
    var blockTime: BlockTime?
    var existentialDeposit: Balance?
    var currentBlock: BlockNumber?
    var catalogue: SubtensorSubnetCatalogue?
    var subnetLogos: SubtensorSubnetLogos?
    var isSubnetsRefreshForced = false
    var validatorItem: SubtensorValidatorDirectoryItem?
    var validatorRequest: AccountId?
    var preflightRequest: AccountId?
    var holds: [AccountId: SubtensorRootHold]?
    var groupHotkeys: [AccountId: SubtensorGroupHotkeyInfo]?
    var quoteFlow = SubtensorQuoteFlowModel()
    var latestQuote: SubtensorTradeQuote?
    var acceptedQuote: SubtensorTradeQuote?
    var isQuoteFailed = false
    var tradesUnavailable = false
    var costBasis: SubtensorCostBasisState = .loading

    private var feeShape: FeeShape?

    init(
        interactor: SubtensorUnstakeInteractorInputProtocol,
        wireframe: SubtensorStakingSetupWireframeProtocol,
        netuid: UInt16,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        slippage: BigRational,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
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

        if netuid == SubtensorStakingPallet.rootNetuid {
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

    var heldHotkeys: Set<AccountId> {
        guard isRoot, let group, let holds, let currentBlock else {
            return []
        }

        let head = UInt64(currentBlock)

        return Set(group.positions.map(\.hotkey).filter { (holds[$0]?.remainingBlocks(at: head) ?? 0) > 0 })
    }

    var excludedHotkeys: Set<AccountId> {
        let held = heldHotkeys

        guard let group, held.count < group.positions.count else {
            return []
        }

        return held
    }

    func floorAlpha() -> Balance {
        guard let minStake = preflight?.minStake else {
            return 0
        }

        guard !isRoot else {
            return SubtensorGroupUnstakeBasis.floorAlpha(
                minTao: minStake,
                price: SubtensorStakingPallet.alphaPriceScale,
                feeRate: 0
            )
        }

        guard let limitPrice = currentLimitPrice() else {
            return 0
        }

        return SubtensorGroupUnstakeBasis.floorAlpha(
            minTao: minStake,
            price: limitPrice,
            feeRate: latestQuote?.quote.feeRate ?? 0
        )
    }

    func feeOperation(for plan: SubtensorUnstakePlan) -> SubtensorStakingOperation? {
        guard !isRoot else {
            return plan.rootOperation(amount: plan.amount)
        }

        guard let limitPrice = currentLimitPrice(), let spotPrice = currentSpotPrice() else {
            return nil
        }

        let quotedTaoOut = quoteFlow.freshQuote?.quote.sim.taoAmount ??
            plan.amount * spotPrice / SubtensorStakingPallet.alphaPriceScale

        guard quotedTaoOut > 0 else {
            return nil
        }

        return plan.subnetOperation(netuid: netuid, limitPrice: limitPrice, quotedTaoOut: quotedTaoOut, novaFee: nil)
    }
}

extension SubtensorUnstakeSetupPresenter {
    var isRoot: Bool {
        netuid == SubtensorStakingPallet.rootNetuid
    }

    var basis: SubtensorGroupUnstakeBasis? {
        if let group {
            return SubtensorGroupUnstakeBasis.make(
                from: group,
                excluding: excludedHotkeys,
                groupHotkeys: groupHotkeys ?? [:]
            )
        }

        guard positionsState != nil else {
            return nil
        }

        return SubtensorGroupUnstakeBasis(total: 0, available: 0, positions: [])
    }

    var maxAmount: Balance? {
        basis?.max(floor: floorAlpha())
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
        basis?.plan(for: amount, floor: floorAlpha())
    }

    func feePlan() -> SubtensorUnstakePlan? {
        guard let primary = group?.primaryHotkey else {
            return nil
        }

        let amount = inputAmountOrPlaceholder()

        return plan(for: amount) ?? SubtensorUnstakePlan(
            exits: [],
            partials: [SubtensorUnstakeSlice(hotkey: primary, alpha: amount)]
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
        guard let primary = group?.primaryHotkey else {
            return
        }

        preflightRequest = primary
        interactor.refreshPreflight(for: primary, netuid: netuid)
    }

    func loadValidatorIfNeeded() {
        guard let primary = group?.primaryHotkey, primary != validatorRequest, let subnetRef else {
            return
        }

        validatorRequest = primary
        validatorItem = nil
        interactor.loadValidator(primary, on: subnetRef)
    }

    func applyInputChange() {
        refreshFee()
        updateQuote()
        provideViewModel()
    }

    func applyPlanChange(from previousPlan: SubtensorUnstakePlan?) {
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
            primaryHotkey: group?.primaryHotkey,
            validatorName: validatorItem?.name,
            fee: fee,
            price: price,
            quote: quoteFlow.freshQuote,
            isQuoteFailed: isQuoteFailed,
            holdRemainingBlocks: holdRemainingBlocks(for: amount),
            blockTime: blockTime,
            costBasis: costBasis
        )

        view?.didReceive(viewModel: viewModelFactory.createViewModel(for: input, locale: selectedLocale))
    }
}

extension SubtensorUnstakeSetupPresenter: SubtensorQuoteHandling {
    var retryView: ControllerBackedProtocol? { view }
    var retryWireframe: AlertPresentable & FeeRetryable & CommonRetryable { wireframe }
    var quoteInteractor: SubtensorStakingBaseInteractorInputProtocol { interactor }
    var loadingView: LoadableViewProtocol? { view }
    var alphaDisplayInfo: AssetBalanceDisplayInfo { inputDisplayInfo }
}

extension SubtensorUnstakeSetupPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideAmountInputViewModel()
            provideAssetViewModel()
            provideViewModel()
        }
    }
}
