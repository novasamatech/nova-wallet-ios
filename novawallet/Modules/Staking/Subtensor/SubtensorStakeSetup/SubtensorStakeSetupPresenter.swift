import BigInt
import Foundation
import Foundation_iOS

final class SubtensorStakeSetupPresenter {
    weak var view: SubtensorStakeSetupViewProtocol?
    let wireframe: SubtensorStakeSetupWireframeProtocol
    let interactor: SubtensorStakeSetupInteractorInputProtocol
    let logger: LoggerProtocol

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let viewModelFactory: SubtensorStakeSetupViewModelFactory
    let dataValidationFactory: SubtensorValidationFactoryProtocol

    let quickPickVisit: SubtensorQuickPickVisit?
    let rootEntryPresentation: SubtensorRootEntryPresentation
    let browseState: SubtensorSubnetBrowseState

    var mode: SubtensorStakeSetupMode
    var target: SubtensorStakeTarget?
    var validatorState: SubtensorStakeSetupValidatorState = .pending
    var isPresetRequested = false
    var presetError: Error?
    var inputResult: AmountInputResult?
    var balance: AssetBalance?
    var isBalanceLoaded = false
    var price: PriceData?
    var fee: ExtrinsicFeeProtocol?
    var shieldQuote: SubtensorShieldQuote?
    var shieldQuoteOperation: SubtensorOperation?
    var isShieldQuoteResolved = false
    var existentialDeposit: Balance?
    var positionsState: Multistaking.SubtensorState?
    var isPositionsSyncFailed = false
    var preflight: SubtensorPreflight?
    var blockTime: BlockTime?
    var catalogue: SubtensorSubnetCatalogue?
    var subnetLogos: SubtensorSubnetLogos?
    var rankingView: SubtensorRankedSubnets?
    var yields: SubtensorAlphaYields?
    var yieldsNetuid: UInt16?
    var isYieldsResolved = false
    var isSubnetDataRequested = false
    var validatorItem: SubtensorValidatorDirectoryItem?
    var slippage: BigRational
    var quoteFlow = SubtensorQuoteFlowModel()
    var acceptedQuote: SubtensorTradeQuote?
    var isQuoteFailed = false
    var tradesUnavailable = false
    var costBasis: SubtensorCostBasisState = .loading
    var novaFeeRate: BigRational?
    var isConfirmationShown = false
    var isLockedValidatorPending = false

    init(
        interactor: SubtensorStakeSetupInteractorInputProtocol,
        wireframe: SubtensorStakeSetupWireframeProtocol,
        mode: SubtensorStakeSetupMode,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        slippage: BigRational,
        dataValidationFactory: SubtensorValidationFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        viewModelFactory: SubtensorStakeSetupViewModelFactory,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol,
        browseState: SubtensorSubnetBrowseState,
        quickPickVisit: SubtensorQuickPickVisit? = nil,
        rootEntryPresentation: SubtensorRootEntryPresentation = .standard
    ) {
        self.rootEntryPresentation = rootEntryPresentation
        self.browseState = browseState
        self.quickPickVisit = quickPickVisit
        self.interactor = interactor
        self.wireframe = wireframe
        self.mode = mode
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.slippage = slippage
        self.dataValidationFactory = dataValidationFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

extension SubtensorStakeSetupPresenter {
    var transferable: Balance? {
        isBalanceLoaded ? (balance?.transferable ?? 0) : nil
    }

    var subnetRef: SubtensorSubnetRef? {
        target?.subnetRef
    }

    func inputDecimal() -> Decimal? {
        let maxDecimal = (maxAmount ?? 0).decimal(assetInfo: chainAsset.assetDisplayInfo)

        return inputResult?.absoluteValue(from: maxDecimal)
    }

    func inputAmount() -> Balance? {
        inputDecimal()?.toSubstrateAmount(precision: chainAsset.assetDisplayInfo.assetPrecision)
    }

    func startMode() {
        target = mode.initialTarget
        validatorState = .pending
        validatorItem = nil
        isPresetRequested = false
        presetError = nil
        preflight = nil
        quoteFlow = SubtensorQuoteFlowModel()
        isQuoteFailed = false
        tradesUnavailable = false

        if case .quickPick = mode {
            loadQuickPick()
            return
        }

        if case let .buyMore(position) = mode {
            interactor.loadSubnet(netuid: position.netuid)
            interactor.loadCostBasis(for: position.netuid)
        }

        loadSubnetDataIfNeeded()

        if let hotkey = mode.lockedHotkey {
            validatorState = .selected(SubtensorStakeSetupValidator(hotkey: hotkey, name: nil))
        } else if let picked = mode.pickedValidator {
            validatorState = .selected(SubtensorStakeSetupValidator(hotkey: picked.hotkey, name: picked.name))
            validatorItem = picked
        }

        applyTargetIfReady()
    }

    func applyTargetIfReady() {
        guard target != nil else {
            provideViewModel()
            return
        }

        if let hotkey = mode.lockedHotkey, let subnetRef {
            isLockedValidatorPending = true
            interactor.loadLockedValidator(hotkey, on: subnetRef)
        }

        requestPresetIfReady()
        refreshPreflight()
        fee = nil
        resetShieldQuote()
        refreshFee()
        updateQuote()
        provideViewModel()
    }

    func requestPresetIfReady() {
        guard
            case .pending = validatorState,
            !isPresetRequested,
            positionsState != nil || isPositionsSyncFailed,
            let subnetRef else {
            return
        }

        isPresetRequested = true

        interactor.presetValidator(on: subnetRef, existingHotkey: existingPrimaryHotkey(on: subnetRef.netuid))
    }

    func retryPreset() {
        presetError = nil
        validatorState = .pending
        isPresetRequested = false

        requestPresetIfReady()
        provideViewModel()
    }

    func existingPrimaryHotkey(on netuid: UInt16) -> AccountId? {
        positionsState.flatMap { SubtensorPortfolioBuilder.build(state: $0).group(netuid: netuid)?.primaryHotkey }
    }

    func applyValidator(_ item: SubtensorValidatorDirectoryItem) {
        validatorState = .selected(SubtensorStakeSetupValidator(hotkey: item.hotkey, name: item.name))
        validatorItem = item
        presetError = nil
        preflight = nil

        refreshPreflight()
        refreshFee()
        provideViewModel()
    }

    func refreshPreflight() {
        guard let hotkey = validatorState.validator?.hotkey, let target else {
            return
        }

        interactor.refreshPreflight(for: hotkey, netuid: target.netuid)
    }

    func currentLimitPrice() -> Balance? {
        let spot = quoteFlow.freshQuote?.quote.spotPrice ?? target?.listedPrice

        return target?.stakeLimitPrice(spot: spot, tolerance: slippage)
    }

    func feeOperation() -> SubtensorOperation? {
        guard let target else {
            return nil
        }

        let hotkey = validatorState.validator?.hotkey ?? AccountId.zeroAccountId(of: chainAsset.chain.accountIdSize)

        let amount = inputAmountOrPlaceholder()

        switch target {
        case .root:
            return .rootStake(hotkey: hotkey, amount: amount)
        case .subnet:
            guard let limitPrice = currentLimitPrice() else {
                return nil
            }

            return .subnetBuy(
                hotkey: hotkey,
                netuid: target.netuid,
                grossTao: amount,
                limitPrice: limitPrice,
                novaFee: nil
            )
        }
    }

    func refreshFee() {
        guard let operation = feeOperation() else {
            return
        }

        interactor.estimateFee(for: operation)

        shieldQuoteOperation = operation
        interactor.estimateShieldQuote(for: operation)
    }

    func quoteRequest() -> SubtensorTradeQuoteRequest? {
        guard case let .subnet(info, _) = target else {
            return nil
        }

        return .buy(netuid: info.netuid, grossTao: inputAmountOrPlaceholder(), tolerance: slippage)
    }

    func applyInputChange() {
        refreshFee()
        updateQuote()
        provideAssetViewModel()
        provideViewModel()
    }

    func applyMaxChange() {
        if case .rate = inputResult {
            provideAmountInputViewModel()
            updateQuote()
        }

        provideAssetViewModel()
        provideViewModel()
    }

    func provideAmountInputViewModel() {
        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(inputDecimal()).value(for: selectedLocale)

        view?.didReceiveAmount(inputViewModel: viewModel)
    }

    func provideAssetViewModel() {
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputDecimal() ?? 0,
            balance: (transferable ?? 0).decimal(assetInfo: chainAsset.assetDisplayInfo),
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAmountAsset(viewModel: viewModel)
    }
}

extension SubtensorStakeSetupPresenter: SubtensorQuoteHandling {
    var isRoot: Bool { target?.isRoot == true }
    var retryView: ControllerBackedProtocol? { view }
    var retryWireframe: AlertPresentable & FeeRetryable & CommonRetryable { wireframe }
    var quoteInteractor: SubtensorBaseInteractorInputProtocol { interactor }
    var loadingView: LoadableViewProtocol? { view }

    var alphaDisplayInfo: AssetBalanceDisplayInfo {
        guard let target else {
            return chainAsset.assetDisplayInfo
        }

        return chainAsset.assetDisplayInfo.subtensorAlpha(netuid: target.netuid, catalogue: catalogue)
    }
}

extension SubtensorStakeSetupPresenter: SubtensorStakeSetupPresenterProtocol {
    func setup() {
        provideAmountInputViewModel()
        provideAssetViewModel()

        interactor.setup()
        interactor.loadBlockTime()
        interactor.loadNovaFeeRate()
        interactor.loadExistentialDeposit()

        startMode()
    }

    func didAppear() {
        guard isConfirmationShown else {
            return
        }

        isConfirmationShown = false
        forceQuoteRefresh()
    }

    func retry() {
        if presetError != nil {
            retryPreset()
        } else {
            retryQuickPick()
        }
    }

    func selectValidator() {
        if case .addStake = mode {
            showLockedValidatorInfo()
            return
        }

        guard !mode.isLocked, let target else {
            return
        }

        wireframe.showValidatorSelection(
            from: view,
            target: target,
            selectedHotkey: validatorState.validator?.hotkey,
            delegate: self
        )
    }

    func getTao() {
        wireframe.showGetTokenOptions(
            from: view,
            purchaseHandler: self,
            destinationChainAsset: chainAsset,
            locale: selectedLocale
        )
    }

    func proceed() {
        if case .subnetPick = mode, validatorState == .none {
            selectValidator()
            return
        }

        guard
            let target,
            validatorState.validator != nil,
            let amount = inputAmount(), amount > 0 else {
            return
        }

        let dependencies = createValidationDependencies(for: target)

        guard var model = createConfirmModel(for: dependencies) else {
            return
        }

        dataValidationFactory.validateStake(for: dependencies, locale: selectedLocale) { [weak self] in
            guard let self else {
                return
            }

            view?.didStopLoading()
            model.acknowledgedQuote = acknowledgedQuote(for: dependencies.quoteContext)
            isConfirmationShown = true
            wireframe.showConfirmation(from: view, model: model)
        }
    }
}
