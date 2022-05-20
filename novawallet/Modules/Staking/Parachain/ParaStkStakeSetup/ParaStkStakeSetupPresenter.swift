import Foundation
import SoraFoundation
import BigInt

final class ParaStkStakeSetupPresenter {
    weak var view: ParaStkStakeSetupViewProtocol?
    let wireframe: ParaStkStakeSetupWireframeProtocol
    let interactor: ParaStkStakeSetupInteractorInputProtocol

    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    private var inputResult: AmountInputResult?
    private var fee: BigUInt?
    private var balance: AssetBalance?
    private var minTechStake: BigUInt?
    private var price: PriceData?
    private var rewardCalculator: ParaStakingRewardCalculatorEngineProtocol?

    private var collatorDisplayAddress: DisplayAddress?
    private var collatorMetadata: ParachainStaking.CandidateMetadata?

    private lazy var displayAddressFactory = DisplayAddressViewModelFactory()

    let logger: LoggerProtocol

    init(
        interactor: ParaStkStakeSetupInteractorInputProtocol,
        wireframe: ParaStkStakeSetupWireframeProtocol,
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func balanceMinusFee() -> Decimal {
        let balanceValue = balance?.transferable ?? 0
        let feeValue = fee ?? 0

        let precision = chainAsset.assetDisplayInfo.assetPrecision

        guard
            let balance = Decimal.fromSubstrateAmount(balanceValue, precision: precision),
            let fee = Decimal.fromSubstrateAmount(feeValue, precision: precision) else {
            return 0
        }

        return balance - fee
    }

    private func provideAmountInputViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee())

        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(
            inputAmount
        ).value(for: selectedLocale)

        view?.didReceiveAmount(inputViewModel: viewModel)
    }

    private func provideAssetViewModel() {
        let balanceDecimal = balance.flatMap { value in
            Decimal.fromSubstrateAmount(
                value.transferable,
                precision: chainAsset.assetDisplayInfo.assetPrecision
            )
        }

        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            balanceMinusFee(),
            balance: balanceDecimal ?? 0.0,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAssetBalance(viewModel: viewModel)
    }

    private func provideMinStakeViewModel() {
        let minStake: BigUInt?
        if
            let minTechStake = minTechStake,
            let minRewardableStake = collatorMetadata?.minRewardableStake(for: minTechStake) {
            minStake = minRewardableStake
        } else {
            minStake = minTechStake
        }

        let viewModel: BalanceViewModelProtocol? = minStake.flatMap { amount in
            guard let decimaAmount = Decimal.fromSubstrateAmount(
                amount,
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ) else {
                return nil
            }

            return balanceViewModelFactory.balanceFromPrice(
                decimaAmount,
                priceData: price
            ).value(for: selectedLocale)
        }

        view?.didReceiveMinStake(viewModel: viewModel)
    }

    private func provideFeeViewModel() {
        let optFeeDecimal = fee.flatMap { value in
            Decimal.fromSubstrateAmount(
                value,
                precision: chainAsset.assetDisplayInfo.assetPrecision
            )
        }

        if let feeDecimal = optFeeDecimal {
            let viewModel = balanceViewModelFactory.balanceFromPrice(
                feeDecimal,
                priceData: price
            ).value(for: selectedLocale)

            view?.didReceiveFee(viewModel: viewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }

    private func provideRewardsViewModel() {}

    private func provideCollatorViewModel() {
        if let collatorDisplayAddress = collatorDisplayAddress {
            let displayViewModel = displayAddressFactory.createViewModel(from: collatorDisplayAddress)
            view?.didReceiveCollator(viewModel: displayViewModel)
        } else {
            view?.didReceiveCollator(viewModel: nil)
        }
    }

    private func refreshFee() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0
        let precicion = chainAsset.assetDisplayInfo.assetPrecision

        guard let amount = inputAmount.toSubstrateAmount(precision: precicion) else {
            return
        }

        interactor.estimateFee(
            amount,
            collator: nil,
            collatorDelegationsCount: 0,
            delegationsCount: 0
        )
    }
}

extension ParaStkStakeSetupPresenter: ParaStkStakeSetupPresenterProtocol {
    func setup() {
        provideAmountInputViewModel()

        provideCollatorViewModel()
        provideAssetViewModel()
        provideMinStakeViewModel()
        provideFeeViewModel()

        interactor.setup()
    }

    func selectCollator() {
        interactor.rotateSelectedCollator()
    }

    func updateAmount(_: Decimal?) {}

    func selectAmountPercentage(_: Float) {}

    func proceed() {}
}

extension ParaStkStakeSetupPresenter: ParaStkStakeSetupInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        self.balance = balance

        provideAssetViewModel()
    }

    func didReceiveRewardCalculator(_ calculator: ParaStakingRewardCalculatorEngineProtocol) {
        rewardCalculator = calculator

        provideRewardsViewModel()
    }

    func didReceivePrice(_ priceData: PriceData?) {
        price = priceData

        provideAssetViewModel()
        provideMinStakeViewModel()
        provideFeeViewModel()
    }

    func didReceiveFee(_ result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            fee = BigUInt(dispatchInfo.fee)

            provideFeeViewModel()
        case let .failure(error):
            logger.error("Did receive error: \(error)")

            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        }
    }

    func didReceiveMinTechStake(_ minStake: BigUInt) {
        minTechStake = minStake

        provideMinStakeViewModel()
    }

    func didCompleteSetup() {
        refreshFee()

        interactor.rotateSelectedCollator()
    }

    func didReceiveCollator(
        metadata: ParachainStaking.CandidateMetadata?,
        address: DisplayAddress
    ) {
        collatorMetadata = metadata
        collatorDisplayAddress = address

        provideCollatorViewModel()
        provideMinStakeViewModel()
    }

    func didReceiveError(_ error: Error) {
        _ = wireframe.present(error: error, from: view, locale: selectedLocale)

        logger.error("Did receive error: \(error)")
    }
}

extension ParaStkStakeSetupPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideAssetViewModel()
            provideAmountInputViewModel()
            provideMinStakeViewModel()
            provideFeeViewModel()
            provideRewardsViewModel()
        }
    }
}
