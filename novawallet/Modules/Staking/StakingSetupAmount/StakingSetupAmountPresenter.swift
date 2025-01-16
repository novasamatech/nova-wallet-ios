import Foundation
import Foundation_iOS
import BigInt

final class StakingSetupAmountPresenter {
    weak var view: StakingSetupAmountViewProtocol?
    let wireframe: StakingSetupAmountWireframeProtocol
    let interactor: StakingSetupAmountInteractorInputProtocol
    let viewModelFactory: StakingAmountViewModelFactoryProtocol
    let stakingTypeViewModelFactory: SelectedStakingViewModelFactoryProtocol
    let chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: RelaychainStakingValidatorFacadeProtocol
    let balanceDerivationFactory: StakingTypeBalanceFactoryProtocol
    let recommendsMultipleStakings: Bool
    let chainAsset: ChainAsset
    let accountId: AccountId
    let logger: LoggerProtocol

    private var setupMethod: StakingSelectionMethod = .recommendation(nil)

    private var assetBalance: AssetBalance?
    private var existentialDeposit: BigUInt?
    private var buttonState: ButtonState = .startState
    private var inputResult: AmountInputResult? {
        didSet {
            if inputResult != nil {
                buttonState = .continueState(enabled: true)
            } else {
                buttonState = .continueState(enabled: false)
            }

            provideButtonState()
        }
    }

    private var pendingRecommendationAmount: BigUInt?
    private var priceData: PriceData?
    private var fee: ExtrinsicFeeProtocol?
    private var pendingFeeId: TransactionFeeId?
    private var assetLocks: AssetLocks?

    init(
        interactor: StakingSetupAmountInteractorInputProtocol,
        wireframe: StakingSetupAmountWireframeProtocol,
        viewModelFactory: StakingAmountViewModelFactoryProtocol,
        stakingTypeViewModelFactory: SelectedStakingViewModelFactoryProtocol,
        chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        balanceDerivationFactory: StakingTypeBalanceFactoryProtocol,
        dataValidatingFactory: RelaychainStakingValidatorFacadeProtocol,
        accountId: AccountId,
        chainAsset: ChainAsset,
        recommendsMultipleStakings: Bool,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.stakingTypeViewModelFactory = stakingTypeViewModelFactory
        self.chainAssetViewModelFactory = chainAssetViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.balanceDerivationFactory = balanceDerivationFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.recommendsMultipleStakings = recommendsMultipleStakings
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func provideBalanceModel() {
        let viewModel = viewModelFactory.balance(
            amount: availableBalanceInPlank(),
            chainAsset: chainAsset,
            locale: selectedLocale
        )

        view?.didReceive(balance: viewModel)
    }

    private func provideTitle() {
        let title = R.string.localizable.stakingStakeFormat(
            chainAsset.assetDisplayInfo.symbol,
            preferredLanguages: selectedLocale.rLanguages
        )
        view?.didReceive(title: title)
    }

    private func provideButtonState() {
        view?.didReceiveButtonState(
            title: buttonState.title.value(for: selectedLocale),
            enabled: buttonState.enabled
        )
    }

    private func provideChainAssetViewModel() {
        guard let asset = chainAsset.chain.utilityAsset() else {
            return
        }

        let chain = chainAsset.chain
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        let viewModel = chainAssetViewModelFactory.createViewModel(from: chainAsset)
        view?.didReceiveInputChainAsset(viewModel: viewModel)
    }

    private func provideAmountPriceViewModel() {
        if chainAsset.chain.utilityAsset()?.priceId != nil {
            let priceData = priceData ?? PriceData.zero()

            let price = balanceViewModelFactory.priceFromAmount(
                inputAmount(),
                priceData: priceData
            ).value(for: selectedLocale)

            view?.didReceiveAmountInputPrice(viewModel: price)
        } else {
            view?.didReceiveAmountInputPrice(viewModel: nil)
        }
    }

    private func provideAmountInputViewModel() {
        let amount = inputResult != nil ? inputAmount() : nil
        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(
            amount
        ).value(for: selectedLocale)

        view?.didReceiveAmount(inputViewModel: viewModel)
    }

    private func stakeableBalanceMinusFee() -> Decimal {
        let feeValue = fee?.amountForCurrentAccount ?? 0
        guard
            let precision = chainAsset.chain.utilityAsset()?.displayInfo.assetPrecision,
            let balance = stakeableBalance(),
            let feeDecimal = Decimal.fromSubstrateAmount(feeValue, precision: precision) else {
            return 0
        }

        return balance >= feeDecimal ? balance - feeDecimal : 0
    }

    private func inputAmount() -> Decimal {
        inputResult?.absoluteValue(from: stakeableBalanceMinusFee()) ?? 0
    }

    private func inputAmountInPlank() -> BigUInt {
        inputAmount().toSubstrateAmount(precision: chainAsset.assetDisplayInfo.assetPrecision) ?? 0
    }

    private func availableBalance() -> Decimal? {
        availableBalanceInPlank().flatMap { $0.decimal(precision: chainAsset.asset.precision) }
    }

    private func stakeableBalance() -> Decimal? {
        stakeableBalanceInPlank().flatMap { $0.decimal(precision: chainAsset.asset.precision) }
    }

    private func availableBalanceInPlank() -> BigUInt? {
        balanceDerivationFactory.getAvailableBalance(
            from: assetBalance,
            stakingMethod: setupMethod
        )
    }

    private func stakeableBalanceInPlank() -> BigUInt? {
        balanceDerivationFactory.getStakeableBalance(
            from: assetBalance,
            existentialDeposit: existentialDeposit,
            stakingMethod: setupMethod
        )
    }

    private func manualAvailableBalanceInPlank(for stakingOption: SelectedStakingOption) -> BigUInt? {
        switch stakingOption {
        case .direct:
            return assetBalance?.freeInPlank
        case .pool:
            return assetBalance?.transferable
        }
    }

    private func updateAfterAmountChanged() {
        refreshFee()
        provideAmountPriceViewModel()
        updateRecommendationIfNeeded()
    }

    private func refreshFee() {
        guard let stakingOption = setupMethod.selectedStakingOption else {
            return
        }

        let amount = inputAmountInPlank()

        let feeId = StartStakingFeeIdFactory.generateFeeId(for: stakingOption, amount: amount)

        fee = nil
        pendingFeeId = feeId

        interactor.estimateFee(for: stakingOption, amount: amount, feeId: feeId)
    }

    private func provideStakingTypeViewModel() {
        switch setupMethod {
        case let .recommendation(stakingRecommendation):
            if inputResult == nil, recommendsMultipleStakings {
                view?.didReceive(stakingType: nil)
            } else if let stakingType = stakingRecommendation?.staking {
                provideRecommendedStakingTypeViewModel(for: stakingType)
            } else {
                view?.didReceive(stakingType: .loading)
            }
        case let .manual(stakingManual):
            provideManualStakingTypeViewModel(for: stakingManual)
        }
    }

    private func provideManualStakingTypeViewModel(for model: RelaychainStakingManual) {
        let innerViewModel: StakingTypeViewModel.TypeModel

        switch model.staking {
        case let .direct(validators):
            let validatorViewModel = stakingTypeViewModelFactory.createValidator(
                for: validators,
                displaysRecommended: model.usedRecommendation,
                locale: selectedLocale
            )

            innerViewModel = .direct(validatorViewModel)
        case let .pool(selectedPool):
            let poolViewModel = stakingTypeViewModelFactory.createPool(
                for: selectedPool,
                chainAsset: chainAsset,
                displaysRecommended: model.usedRecommendation,
                locale: selectedLocale
            )

            innerViewModel = .pools(poolViewModel)
        }

        let maxApy = viewModelFactory.maxApy(for: model.staking, locale: selectedLocale)

        let stakingType = StakingTypeViewModel(
            type: innerViewModel,
            maxApy: maxApy,
            shouldEnableSelection: true
        )

        view?.didReceive(stakingType: .loaded(value: stakingType))
    }

    private func provideRecommendedStakingTypeViewModel(for model: SelectedStakingOption) {
        let viewModel = stakingTypeViewModelFactory.createRecommended(
            for: model,
            locale: selectedLocale
        )

        let maxApy = viewModelFactory.maxApy(for: model, locale: selectedLocale)

        let stakingType = StakingTypeViewModel(
            type: .recommended(viewModel),
            maxApy: maxApy,
            shouldEnableSelection: true
        )

        view?.didReceive(stakingType: .loaded(value: stakingType))
    }

    private func updateRecommendationIfNeeded() {
        let amount = inputAmountInPlank()

        guard amount != pendingRecommendationAmount, setupMethod.isRecommendation else {
            return
        }

        pendingRecommendationAmount = amount
        setupMethod = .recommendation(nil)

        provideStakingTypeViewModel()

        interactor.updateRecommendation(for: amount)
    }
}

extension StakingSetupAmountPresenter: StakingSetupAmountPresenterProtocol {
    func setup() {
        interactor.setup()

        provideTitle()
        provideBalanceModel()
        provideChainAssetViewModel()
        provideAmountPriceViewModel()
        provideAmountInputViewModel()
        provideButtonState()
        provideStakingTypeViewModel()
        refreshFee()

        if !recommendsMultipleStakings {
            updateRecommendationIfNeeded()
        }
    }

    func updateAmount(_ newValue: Decimal?) {
        inputResult = newValue.map { .absolute($0) }
        updateAfterAmountChanged()
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))

        provideAmountInputViewModel()
        updateAfterAmountChanged()
    }

    func selectStakingType() {
        if chainAsset.asset.hasMultipleStakingOptions {
            wireframe.showStakingTypeSelection(
                from: view,
                method: setupMethod,
                amount: inputAmountInPlank(),
                delegate: self
            )
        } else if case let .direct(validators) = setupMethod.selectedStakingOption {
            let delegateFacade = StakingSetupTypeEntityFacade(
                selectedMethod: setupMethod,
                delegate: self
            )

            wireframe.showSelectValidators(
                from: view,
                selectedValidators: validators,
                delegate: delegateFacade
            )
        }
    }

    func proceed() {
        var currentInputAmount = inputAmount()

        let defaultValidations: [DataValidating] = dataValidatingFactory.createValidations(
            from: setupMethod,
            params: .init(
                chainAsset: chainAsset,
                stakingAmount: currentInputAmount,
                availableBalance: availableBalanceInPlank(),
                assetBalance: assetBalance,
                fee: fee,
                existentialDeposit: existentialDeposit,
                feeRefreshClosure: { [weak self] in
                    self?.refreshFee()
                }, stakeUpdateClosure: { newAmount in
                    currentInputAmount = newAmount
                }
            ),
            locale: selectedLocale
        )

        let recommendedValidations = setupMethod.recommendation?.validationFactory?.createValidations(
            for: .init(
                accountId: accountId,
                stakingAmount: currentInputAmount,
                assetBalance: assetBalance,
                assetLocks: assetLocks,
                fee: fee,
                existentialDeposit: existentialDeposit,
                stakeUpdateClosure: { newStake in
                    currentInputAmount = newStake
                },
                onAsyncProgress: .init(
                    willStart: { [weak self] in
                        self?.view?.didStartLoading()
                    },
                    didComplete: { [weak self] _ in
                        self?.view?.didStopLoading()
                    }
                )
            ),
            controller: view,
            balanceViewModelFactory: balanceViewModelFactory,
            presentable: wireframe,
            locale: selectedLocale
        ) ?? []

        let validators = defaultValidations + recommendedValidations
        DataValidationRunner(validators: validators).runValidation { [weak self] in
            guard let stakingOption = self?.setupMethod.selectedStakingOption else {
                return
            }

            self?.wireframe.showConfirmation(
                from: self?.view,
                stakingOption: stakingOption,
                amount: currentInputAmount
            )
        }
    }
}

extension StakingSetupAmountPresenter: StakingSetupAmountInteractorOutputProtocol {
    func didReceive(price: PriceData?) {
        priceData = price
        provideAmountPriceViewModel()
    }

    func didReceive(assetBalance: AssetBalance) {
        self.assetBalance = assetBalance
        provideBalanceModel()

        if case .rate = inputResult {
            // fee and recommendation might change because staking amount depends on balance
            provideAmountInputViewModel()
            updateRecommendationIfNeeded()
            refreshFee()
        }
    }

    func didReceive(existentialDeposit: BigUInt) {
        self.existentialDeposit = existentialDeposit
    }

    func didReceive(fee: ExtrinsicFeeProtocol, feeId: TransactionFeeId) {
        logger.debug("Did receive fee: \(String(describing: fee))")

        guard pendingFeeId == feeId else {
            return
        }

        self.fee = fee
        pendingFeeId = nil

        if case .rate = inputResult {
            provideAmountInputViewModel()
            updateRecommendationIfNeeded()
        }
    }

    func didReceive(recommendation: RelaychainStakingRecommendation, amount: BigUInt) {
        logger.debug("Did receive recommendation for amount: \(amount)")

        // check that we are waiting recommendation for particular amount
        guard pendingRecommendationAmount == amount, setupMethod.isRecommendation else {
            return
        }

        setupMethod = .recommendation(recommendation)

        // display balance respects staking type
        provideBalanceModel()

        provideStakingTypeViewModel()
        refreshFee()
    }

    func didReceive(locks: AssetLocks) {
        assetLocks = locks
    }

    func didReceive(error: StakingSetupAmountError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .assetBalance, .price, .locks:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case let .fee(_, feeId):
            guard feeId == pendingFeeId else {
                return
            }

            pendingFeeId = nil

            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        case .recommendation:
            guard setupMethod.isRecommendation else {
                return
            }

            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeRecommendationSetup()
            }
        case .existentialDeposit:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryExistentialDeposit()
            }
        }
    }
}

extension StakingSetupAmountPresenter: Localizable {
    func applyLocalization() {
        guard view?.isSetup == true else {
            return
        }

        provideBalanceModel()
        provideButtonState()
        provideTitle()
        provideAmountInputViewModel()
        provideAmountPriceViewModel()
        provideStakingTypeViewModel()
    }
}

extension StakingSetupAmountPresenter: StakingTypeDelegate {
    func changeStakingType(method: StakingSelectionMethod) {
        pendingRecommendationAmount = nil

        setupMethod = method

        provideBalanceModel()
        provideStakingTypeViewModel()
        updateRecommendationIfNeeded()
        refreshFee()
    }
}
