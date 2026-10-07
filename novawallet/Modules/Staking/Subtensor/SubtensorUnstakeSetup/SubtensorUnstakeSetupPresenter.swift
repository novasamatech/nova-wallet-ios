import BigInt
import Foundation
import Foundation_iOS

final class SubtensorUnstakeSetupPresenter {
    weak var view: SubtensorUnstakeSetupViewProtocol?
    let wireframe: SubtensorUnstakeSetupWireframeProtocol
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
    var existentialDeposit: Balance?
    var currentBlock: BlockNumber?
    var catalogue: SubtensorSubnetCatalogue?
    var isCatalogueRefreshForced = false
    var subnetLogos: SubtensorSubnetLogos?
    var isSubnetsRefreshForced = false
    var validatorItem: SubtensorValidatorDirectoryItem?
    var validatorRequest: AccountId?
    var preflightRequest: AccountId?
    var holds: [AccountId: SubtensorRootHold]?
    var quoteFlow = SubtensorQuoteFlowModel()
    var isQuoteFailed = false
    var tradesUnavailable = false
    var costBasis: SubtensorCostBasisState = .loading

    private var feeShape: FeeShape?

    init(
        interactor: SubtensorUnstakeInteractorInputProtocol,
        wireframe: SubtensorUnstakeSetupWireframeProtocol,
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
    enum FeeShape: Equatable {
        case partial(AccountId)
        case exitAll([AccountId])
    }

    func shape(of operation: SubtensorStakingOperation) -> FeeShape? {
        switch operation {
        case let .rootUnstake(hotkey, _), let .subnetSell(hotkey, _, _, _, _):
            return .partial(hotkey)
        case let .rootUnstakeAll(hotkeys), let .subnetSellAll(hotkeys, _, _, _):
            return .exitAll(hotkeys)
        case .rootStake, .rootClaim, .subnetBuy:
            return nil
        }
    }
}

extension SubtensorUnstakeSetupPresenter {
    var isRoot: Bool {
        netuid == SubtensorStakingPallet.rootNetuid
    }

    var basis: SubtensorGroupUnstakeBasis? {
        if let group {
            return SubtensorGroupUnstakeBasis.make(from: group)
        }

        guard positionsState != nil else {
            return nil
        }

        return SubtensorGroupUnstakeBasis(total: 0, primaryAlpha: 0, available: 0, hotkeys: [])
    }

    var maxAmount: Balance? {
        guard let basis else {
            return nil
        }

        guard isRoot, basis.canExitAll, remainingHoldBlocks(for: basis.hotkeys) != nil else {
            return basis.max
        }

        return basis.partialCap
    }

    var inputDisplayInfo: AssetBalanceDisplayInfo {
        viewModelFactory.inputDisplayInfo(for: netuid, catalogue: catalogue)
    }

    var subnetRef: SubtensorSubnetRef? {
        target.map { SubtensorSubnetRef(netuid: $0.netuid, registeredAt: $0.subnetInfo?.networkRegisteredAt ?? 0) }
    }

    func inputAmount() -> Balance? {
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

    func exitHotkeys(for amount: Balance?) -> [AccountId]? {
        guard
            let amount,
            let hotkeys = basis?.exitHotkeys(for: amount),
            remainingHoldBlocks(for: hotkeys) == nil else {
            return nil
        }

        return hotkeys
    }

    func remainingHoldBlocks(for hotkeys: [AccountId]) -> UInt64? {
        guard isRoot, let holds, let currentBlock else {
            return nil
        }

        let remaining = hotkeys.compactMap { holds[$0]?.remainingBlocks(at: UInt64(currentBlock)) }.max() ?? 0

        return remaining > 0 ? remaining : nil
    }

    func holdRemaining(for amount: Balance?) -> TimeInterval? {
        guard let primary = group?.primaryHotkey else {
            return nil
        }

        let hotkeys = exitHotkeys(for: amount) ?? [primary]

        guard let blocks = remainingHoldBlocks(for: hotkeys) else {
            return nil
        }

        return (TimeInterval(blocks) * TimeInterval(SubtensorStakingFlowConstants.blockTimeMillis)).seconds
    }

    func currentSpotPrice() -> Balance? {
        quoteFlow.freshQuote?.quote.spotPrice ?? target?.listedPrice
    }

    func currentLimitPrice() -> Balance? {
        target?.unstakeLimitPrice(spot: currentSpotPrice(), tolerance: slippage)
    }

    func placeholderAmount() -> Balance {
        Decimal(1).toSubstrateAmount(precision: inputDisplayInfo.assetPrecision) ?? 1
    }

    func feeOperation() -> SubtensorStakingOperation? {
        guard let primary = group?.primaryHotkey else {
            return nil
        }

        let amount = inputAmount().flatMap { $0 > 0 ? $0 : nil } ?? placeholderAmount()
        let exitHotkeys = exitHotkeys(for: amount)

        guard !isRoot else {
            return exitHotkeys.map { .rootUnstakeAll(hotkeys: $0) } ?? .rootUnstake(hotkey: primary, amount: amount)
        }

        guard let limitPrice = currentLimitPrice(), let spotPrice = currentSpotPrice() else {
            return nil
        }

        let quotedTaoOut = quoteFlow.freshQuote?.quote.sim.taoAmount ??
            amount * spotPrice / SubtensorStakingPallet.alphaPriceScale

        guard quotedTaoOut > 0 else {
            return nil
        }

        if let exitHotkeys {
            return .subnetSellAll(
                hotkeys: exitHotkeys,
                netuid: netuid,
                limitPrice: limitPrice,
                quotedTaoOut: quotedTaoOut
            )
        }

        return .subnetSell(
            hotkey: primary,
            netuid: netuid,
            alpha: amount,
            limitPrice: limitPrice,
            quotedTaoOut: quotedTaoOut
        )
    }

    func refreshFee() {
        guard let operation = feeOperation() else {
            return
        }

        let newShape = shape(of: operation)

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

        let amount = inputAmount().flatMap { $0 > 0 ? $0 : nil } ?? placeholderAmount()

        return .sell(netuid: netuid, alpha: amount, tolerance: slippage)
    }

    func updateQuote() {
        if let request = quoteFlow.updateRequest(quoteRequest()) {
            isQuoteFailed = false
            interactor.refreshQuote(for: request)
        }
    }

    func forceQuoteRefresh() {
        let request = quoteRequest()

        _ = quoteFlow.updateRequest(request)

        if let request {
            interactor.refreshQuote(for: request)
        }
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
            holdRemaining: holdRemaining(for: amount),
            costBasis: costBasis
        )

        view?.didReceive(viewModel: viewModelFactory.createViewModel(for: input, locale: selectedLocale))
    }
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
