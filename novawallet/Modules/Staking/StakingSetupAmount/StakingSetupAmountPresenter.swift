import Foundation
import SoraFoundation
import BigInt

struct ButtonState {
    let title: LocalizableResource<String>
    let enabled: Bool

    static let startState = ButtonState(
        title: LocalizableResource {
            R.string.localizable.transferSetupEnterAmount(preferredLanguages: $0.rLanguages)
        },
        enabled: false
    )

    static func continueState(enabled: Bool) -> ButtonState {
        .init(
            title: LocalizableResource {
                R.string.localizable.commonContinue(preferredLanguages: $0.rLanguages)
            },
            enabled: enabled
        )
    }
}

final class StakingSetupAmountPresenter {
    weak var view: StakingSetupAmountViewProtocol?
    let wireframe: StakingSetupAmountWireframeProtocol
    let interactor: StakingSetupAmountInteractorInputProtocol
    let viewModelFactory: StakingAmountViewModelFactoryProtocol
    let chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    private var chainAsset: ChainAsset?
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
    private var fee: BigUInt?

    init(
        interactor: StakingSetupAmountInteractorInputProtocol,
        wireframe: StakingSetupAmountWireframeProtocol,
        viewModelFactory: StakingAmountViewModelFactoryProtocol,
        chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chainAssetViewModelFactory = chainAssetViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.localizationManager = localizationManager
    }

    private func provideBalanceModel() {
        guard let chainAsset = chainAsset,
              let assetBalance = assetBalance else {
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
        guard let chainAsset = chainAsset else {
            return
        }

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
        guard let asset = chainAsset?.chain.utilityAsset(), let chain = chainAsset?.chain else {
            return
        }

        let chainAsset = ChainAsset(chain: chain, asset: asset)
        let viewModel = chainAssetViewModelFactory.createViewModel(from: chainAsset)
        view?.didReceiveInputChainAsset(viewModel: viewModel)
    }

    private func provideAmountPriceViewModel() {
        guard let chainAsset = chainAsset else {
            return
        }

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
        let feeValue = fee ?? 0

        guard
            let precision = chainAsset?.chain.utilityAsset()?.displayInfo.assetPrecision,
            let balance = Decimal.fromSubstrateAmount(balanceValue, precision: precision),
            let fee = Decimal.fromSubstrateAmount(feeValue, precision: precision) else {
            return 0
        }

        return balance - fee
    }

    private func updateAfterAmountChanged() {
        refreshFee()
        provideAmountPriceViewModel()
        provideStakingTypeModel()
    }

    private func refreshFee() {
        // interactor.estimateFee()
    }

    private func provideStakingTypeModel() {
        guard let stakingType = stakingType else {
            return
        }
        view?.didReceive(stakingType: stakingType)
    }
}

extension StakingSetupAmountPresenter: StakingSetupAmountPresenterProtocol {
    func setup() {
        interactor.setup()
        provideButtonState()
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
    func didReceive(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
        provideBalanceModel()
        provideTitle()
        provideChainAssetViewModel()
        provideAmountPriceViewModel()
    }

    func didReceive(price: PriceData?) {
        priceData = price
    }

    func didReceive(assetBalance: AssetBalance) {
        self.assetBalance = assetBalance
        provideBalanceModel()
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
