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
    let selectedAccount: ChainAccountResponse

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

    private var stakingType: LoadableViewModelState<StakingTypeChoiceViewModel>?

    private var priceData: PriceData?
    private var fee: LoadableViewModelState<BigUInt?> = .loading

    init(
        interactor: StakingSetupAmountInteractorInputProtocol,
        wireframe: StakingSetupAmountWireframeProtocol,
        viewModelFactory: StakingAmountViewModelFactoryProtocol,
        chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chainAssetViewModelFactory = chainAssetViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount

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

    private func provideAmountInputViewModelIfRate() {
        guard case .rate = inputResult else {
            return
        }

        provideAmountInputViewModel()
    }

    private func provideAmountInputViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee())

        inputAmount.map {
            if $0 > 0 {
                stakingType = .loaded(value: StakingTypeChoiceViewModel(
                    title: "Pool staking",
                    subtitle: "Recommended",
                    isRecommended: true
                ))
            }
        }

        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(
            inputAmount
        ).value(for: selectedLocale)

        view?.didReceiveAmount(inputViewModel: viewModel)
    }

    private func balanceMinusFee() -> Decimal {
        let balanceValue = assetBalance?.freeInPlank ?? 0
        let feeValue = fee.value ?? 0
        guard
            let precision = chainAsset.chain.utilityAsset()?.displayInfo.assetPrecision,
            let balance = Decimal.fromSubstrateAmount(balanceValue, precision: precision),
            let feeDecimal = Decimal.fromSubstrateAmount(feeValue ?? 0, precision: precision) else {
            return 0
        }

        return balance - feeDecimal
    }

    private func updateAfterAmountChanged() {
        refreshFee()
        provideAmountPriceViewModel()
        provideStakingTypeModel()
    }

    private func refreshFee() {
        estimateFee()
    }

    private func provideStakingTypeModel() {
        guard let stakingType = stakingType else {
            return
        }
        view?.didReceive(stakingType: stakingType)
    }

    private func estimateFee() {
        guard let amount = StakingConstants.maxAmount.toSubstrateAmount(precision: chainAsset.assetDisplayInfo.assetPrecision),
              let address = selectedAccount.toAddress() else {
            return
        }

        fee = .loading
        let rewardDestination = RewardDestination.payout(account: selectedAccount)
        interactor.estimateFee(for: address, amount: amount, rewardDestination: rewardDestination)
    }

    private func provideFee() {}
}

extension StakingSetupAmountPresenter: StakingSetupAmountPresenterProtocol {
    func setup() {
        interactor.setup()

        provideBalanceModel()
        provideTitle()
        provideChainAssetViewModel()
        provideAmountPriceViewModel()
        provideButtonState()
        estimateFee()
    }

    func updateAmount(_ newValue: Decimal?) {
        inputResult = newValue.map { .absolute($0) }

        newValue.map {
            if $0 > 0 {
                stakingType = .loaded(value: StakingTypeChoiceViewModel(
                    title: "Pool staking",
                    subtitle: "Recommended",
                    isRecommended: true
                ))
            }
        }

        updateAfterAmountChanged()
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))

        provideAmountInputViewModel()

        updateAfterAmountChanged()
    }

    func selectStakingType() {
        wireframe.showStakingTypeSelection(from: view)
    }

    func proceed() {}
}

extension StakingSetupAmountPresenter: StakingSetupAmountInteractorOutputProtocol {
    func didReceive(price: PriceData?) {
        priceData = price
    }

    func didReceive(assetBalance: AssetBalance) {
        self.assetBalance = assetBalance
        provideBalanceModel()
    }

    func didReceive(paymentInfo: RuntimeDispatchInfo) {
        fee = .loaded(value: BigUInt(paymentInfo.fee))
        provideFee()
    }

    func didReceive(error _: StakingSetupAmountError) {}
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
    }
}
