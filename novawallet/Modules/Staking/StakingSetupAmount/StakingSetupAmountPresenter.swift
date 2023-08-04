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
    let chainAsset: ChainAsset
    let logger: LoggerProtocol?

    private var assetBalance: AssetBalance?
    private var buttonState: ButtonState = .startState
    private var inputResult: AmountInputResult? {
        didSet {
            if inputResult != nil {
                buttonState = .continueState(enabled: true)
                provideButtonState()
            }
        }
    }

    private var recommendation: RelaychainStakingRecommendation?
    private var priceData: PriceData?
    private var fee: BigUInt?

    var availableBalance: Decimal? {
        assetBalance.flatMap { $0.freeInPlank.decimal(precision: chainAsset.asset.precision) }
    }

    init(
        interactor: StakingSetupAmountInteractorInputProtocol,
        wireframe: StakingSetupAmountWireframeProtocol,
        viewModelFactory: StakingAmountViewModelFactoryProtocol,
        chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chainAssetViewModelFactory = chainAssetViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chainAsset = chainAsset
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func provideBalanceModel() {
        guard let assetBalance = assetBalance else {
            return
        }

        let viewModel = viewModelFactory.balance(
            amount: assetBalance.freeInPlank,
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
            let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0
            let priceData = priceData ?? PriceData.zero()

            let price = balanceViewModelFactory.priceFromAmount(
                inputAmount,
                priceData: priceData
            ).value(for: selectedLocale)

            view?.didReceiveAmountInputPrice(viewModel: price)
        } else {
            view?.didReceiveAmountInputPrice(viewModel: nil)
        }
    }

    private func provideAmountInputViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee())

        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(
            inputAmount
        ).value(for: selectedLocale)

        view?.didReceiveAmount(inputViewModel: viewModel)
    }

    private func balanceMinusFee() -> Decimal {
        let balanceValue = assetBalance?.freeInPlank ?? 0

        let feeValue = fee ?? 0
        guard
            let precision = chainAsset.chain.utilityAsset()?.displayInfo.assetPrecision,
            let balance = Decimal.fromSubstrateAmount(balanceValue, precision: precision),
            let feeDecimal = Decimal.fromSubstrateAmount(feeValue, precision: precision) else {
            return 0
        }

        return balance - feeDecimal
    }

    private func updateAfterAmountChanged() {
        refreshFee()
        provideAmountPriceViewModel()
    }

    private func refreshFee() {
        estimateFee()
    }

    private func provideStakingTypeModel() {
        if inputResult == nil {
            view?.didReceive(stakingType: .loading)
            view?.didReceive(estimatedRewards: .loading)
        } else if let stakingType = recommendation?.stakingType {
            let viewModel = viewModelFactory.stakingTypeViewModel(stakingType: stakingType)
            view?.didReceive(stakingType: .loaded(value: viewModel))

            let earnupViewModel = viewModelFactory.earnupModel(
                earnings: stakingType.maxApy,
                chainAsset: chainAsset,
                locale: selectedLocale
            )
            view?.didReceive(estimatedRewards: .loaded(value: earnupViewModel))
        } else {
            view?.didReceive(stakingType: nil)
            view?.didReceive(estimatedRewards: nil)
        }
    }

    private func estimateFee() {
        guard
            let amount = StakingConstants.maxAmount.toSubstrateAmount(
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ) else {
            return
        }

        fee = nil
        interactor.estimateFee(for: amount)
    }

    private func updateRecommendation() {
        let inputAmount = inputResult?
            .absoluteValue(from: availableBalance ?? 0)
            .toSubstrateAmount(precision: chainAsset.assetDisplayInfo.assetPrecision)

        interactor.updateRecommendation(for: inputAmount ?? 0)
    }
}

extension StakingSetupAmountPresenter: StakingSetupAmountPresenterProtocol {
    func setup() {
        interactor.setup()

        provideTitle()
        provideBalanceModel()
        provideChainAssetViewModel()
        provideAmountPriceViewModel()
        provideButtonState()
        estimateFee()
    }

    func updateAmount(_ newValue: Decimal?) {
        inputResult = newValue.map { .absolute($0) }
        updateAfterAmountChanged()
        updateRecommendation()
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))

        provideAmountInputViewModel()
        updateAfterAmountChanged()
        updateRecommendation()
    }

    func selectStakingType() {
        wireframe.showStakingTypeSelection(from: view)
    }

    func proceed() {}
}

extension StakingSetupAmountPresenter: StakingSetupAmountInteractorOutputProtocol {
    func didReceive(price: PriceData?) {
        priceData = price
        provideAmountPriceViewModel()
    }

    func didReceive(assetBalance: AssetBalance) {
        self.assetBalance = assetBalance
        provideBalanceModel()
    }

    func didReceive(fee: BigUInt?, stakingOption _: SelectedStakingOption, amount _: BigUInt) {
        self.fee = fee

        provideAmountInputViewModel()
    }

    func didReceive(recommendation: RelaychainStakingRecommendation, amount _: BigUInt) {
        self.recommendation = recommendation
        provideStakingTypeModel()
    }

    func didReceive(error: StakingSetupAmountError) {
        logger?.error("Did receive error: \(error)")

        switch error {
        case .assetBalance, .price:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .fee:
            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        case .recommendation:
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
        provideStakingTypeModel()
    }
}
