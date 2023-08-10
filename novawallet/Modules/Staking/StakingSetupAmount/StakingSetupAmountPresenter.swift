import Foundation
import SoraFoundation
import BigInt

final class StakingSetupAmountPresenter {
    weak var view: StakingSetupAmountViewProtocol?
    let wireframe: StakingSetupAmountWireframeProtocol
    let interactor: StakingSetupAmountInteractorInputProtocol
    let viewModelFactory: StakingAmountViewModelFactoryProtocol
    let chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let balanceDerivationFactory: StakingTypeBalanceFactoryProtocol
    let recommendsMultipleStakings: Bool
    let chainAsset: ChainAsset
    let logger: LoggerProtocol

    private var setupMethod: StakingSelectionMethod = .recommendation(nil)

    private var assetBalance: AssetBalance?
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
    private var fee: BigUInt?
    private var pendingFeeId: TransactionFeeId?
    private var assetLocks: AssetLocks?

    init(
        interactor: StakingSetupAmountInteractorInputProtocol,
        wireframe: StakingSetupAmountWireframeProtocol,
        viewModelFactory: StakingAmountViewModelFactoryProtocol,
        chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        balanceDerivationFactory: StakingTypeBalanceFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        chainAsset: ChainAsset,
        recommendsMultipleStakings: Bool,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chainAssetViewModelFactory = chainAssetViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.balanceDerivationFactory = balanceDerivationFactory
        self.dataValidatingFactory = dataValidatingFactory
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
        let title = R.string.localizable.stakingSetupAmountTitle(
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

    private func balanceMinusFee() -> Decimal {
        let feeValue = fee ?? 0
        guard
            let precision = chainAsset.chain.utilityAsset()?.displayInfo.assetPrecision,
            let balance = availableBalance(),
            let feeDecimal = Decimal.fromSubstrateAmount(feeValue, precision: precision) else {
            return 0
        }

        return balance - feeDecimal
    }

    private func inputAmount() -> Decimal {
        inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0
    }

    private func inputAmountInPlank() -> BigUInt {
        inputAmount().toSubstrateAmount(precision: chainAsset.assetDisplayInfo.assetPrecision) ?? 0
    }

    private func availableBalance() -> Decimal? {
        availableBalanceInPlank().flatMap { $0.decimal(precision: chainAsset.asset.precision) }
    }

    private func availableBalanceInPlank() -> BigUInt? {
        balanceDerivationFactory.getAvailableBalance(
            from: assetBalance,
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
                provideStakingTypeViewModel(for: stakingType)
            } else {
                view?.didReceive(stakingType: .loading)
            }
        case let .manual(stakingManual):
            // TODO: Implement manual factory method
            provideStakingTypeViewModel(for: stakingManual.staking)
        }
    }

    private func provideStakingTypeViewModel(for model: SelectedStakingOption) {
        let viewModel = viewModelFactory.recommendedStakingTypeViewModel(
            for: model,
            chainAsset: chainAsset,
            locale: selectedLocale
        )

        view?.didReceive(stakingType: .loaded(value: viewModel))
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
        wireframe.showStakingTypeSelection(
            from: view,
            method: setupMethod,
            amount: inputAmountInPlank(),
            delegate: self
        )
    }

    // swiftlint:disable:next function_body_length
    func proceed() {
        let currentInputAmount = inputAmount()

        let defaultValidations: [DataValidating] = [
            dataValidatingFactory.hasInPlank(
                fee: fee,
                locale: selectedLocale,
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ) { [weak self] in
                self?.refreshFee()
            },
            dataValidatingFactory.canSpendAmountInPlank(
                balance: availableBalanceInPlank(),
                spendingAmount: currentInputAmount,
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            ),
            dataValidatingFactory.canPayFeeInPlank(
                balance: assetBalance?.transferable,
                fee: fee,
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            ),
            dataValidatingFactory.canPayFeeSpendingAmountInPlank(
                balance: availableBalanceInPlank(),
                fee: fee,
                spendingAmount: currentInputAmount,
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            ),
            dataValidatingFactory.allowsNewNominators(
                flag: setupMethod.restrictions?.allowsNewStakers ?? false,
                locale: selectedLocale
            ),
            dataValidatingFactory.canNominateInPlank(
                amount: currentInputAmount,
                minimalBalance: setupMethod.restrictions?.minJoinStake,
                minNominatorBond: setupMethod.restrictions?.minJoinStake,
                precision: chainAsset.asset.precision,
                locale: selectedLocale
            )
        ]

        let recommendedValidations = setupMethod.recommendation?.validationFactory?.createValidations(
            for: .init(
                stakingAmount: currentInputAmount,
                assetBalance: assetBalance,
                assetLocks: assetLocks,
                fee: fee
            ),
            controller: view,
            balanceViewModelFactory: balanceViewModelFactory,
            presentable: wireframe,
            locale: selectedLocale
        ) ?? []

        DataValidationRunner(validators: defaultValidations + recommendedValidations).runValidation { [weak self] in
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

    func didReceive(fee: BigUInt?, feeId: TransactionFeeId) {
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
        logger.debug("Did receive recommendation: \(recommendation)")

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
