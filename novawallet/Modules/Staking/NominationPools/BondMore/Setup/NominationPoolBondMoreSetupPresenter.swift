import BigInt
import Foundation_iOS

final class NominationPoolBondMoreSetupPresenter: NominationPoolBondMoreBasePresenter {
    weak var view: NominationPoolBondMoreSetupViewProtocol? {
        baseView as? NominationPoolBondMoreSetupViewProtocol
    }

    var wireframe: NominationPoolBondMoreSetupWireframeProtocol? {
        baseWireframe as? NominationPoolBondMoreSetupWireframeProtocol
    }

    var interactor: NominationPoolBondMoreSetupInteractorInputProtocol? {
        baseInteractor as? NominationPoolBondMoreSetupInteractorInputProtocol
    }

    private var inputResult: AmountInputResult?

    func provideTransferrableBalance() {
        guard let balance = assetBalance?.transferable.decimal(precision: chainAsset.asset.precision) else {
            view?.didReceiveTransferable(viewModel: nil)
            return
        }
        let viewModel = balanceViewModelFactory.amountFromValue(balance).value(for: selectedLocale)
        view?.didReceiveTransferable(viewModel: viewModel)
    }

    func provideAmountInputViewModel() {
        let inputAmount = getInputAmount()
        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(
            inputAmount
        ).value(for: selectedLocale)

        view?.didReceiveInput(viewModel: viewModel)
    }

    func provideAssetViewModel() {
        let balance = assetBalance?.transferable.decimal(precision: chainAsset.asset.precision) ?? 0
        let inputAmount = getInputAmount() ?? 0
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: balance,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAssetBalance(viewModel: viewModel)
    }

    override func getInputAmount() -> Decimal? {
        guard let inputResult = inputResult else {
            return nil
        }
        let fee = fee?.amountForCurrentAccount?.decimal(precision: chainAsset.asset.precision) ?? 0
        let transferable = assetBalance?.transferable.decimal(precision: chainAsset.asset.precision) ?? 0
        let balanceCountingEd = assetBalance?.balanceCountingEd.decimal(precision: chainAsset.asset.precision) ?? 0
        let existentialDeposit = assetBalanceExistance?.minBalance.decimal(precision: chainAsset.asset.precision) ?? 0
        let value = max(min(transferable - fee, balanceCountingEd - fee - existentialDeposit), 0)
        return inputResult.absoluteValue(from: value)
    }

    override func updateView() {
        provideAmountInputViewModel()
        provideAssetViewModel()
        provideTransferrableBalance()
        provideFee()
        provideHints()
    }

    override func provideFee() {
        guard let fee = fee?.amount.decimal(precision: chainAsset.asset.precision) else {
            view?.didReceiveFee(viewModel: nil)
            return
        }

        let viewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: price).value(for: selectedLocale)

        view?.didReceiveFee(viewModel: viewModel)
    }

    override func getInputAmountInPlank() -> BigUInt? {
        guard let decimalAmount = getInputAmount() else {
            return nil
        }

        return decimalAmount.toSubstrateAmount(
            precision: chainAsset.assetDisplayInfo.assetPrecision
        )
    }

    override func didReceive(assetBalance: AssetBalance?) {
        super.didReceive(assetBalance: assetBalance)

        provideAssetViewModel()
        provideTransferrableBalance()
        provideAmountInputViewModel()
    }

    override func didReceive(price: PriceData?) {
        super.didReceive(price: price)

        provideAmountInputViewModel()
        provideAssetViewModel()
        provideTransferrableBalance()
        provideFee()
    }

    override func didReceive(assetBalanceExistance: AssetBalanceExistence?) {
        super.didReceive(assetBalanceExistance: assetBalanceExistance)

        provideAmountInputViewModel()
    }
}

extension NominationPoolBondMoreSetupPresenter: NominationPoolBondMoreSetupPresenterProtocol {
    func setup() {
        interactor?.setup()
        refreshFee()
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))

        provideAmountInputViewModel()
        provideAssetViewModel()
        refreshFee()
    }

    func updateAmount(_ newValue: Decimal?) {
        inputResult = newValue.map { AmountInputResult.absolute($0) }

        provideAssetViewModel()
        refreshFee()
    }

    func proceed() {
        let baseValidators = getValidations()

        var currentInputAmount = getInputAmount()

        let setupValidators: [DataValidating] = [
            dataValidatorFactory.poolStakingNotViolatingExistentialDeposit(
                for: .init(
                    stakingAmount: getInputAmount(),
                    assetBalance: assetBalance,
                    fee: fee,
                    existentialDeposit: assetBalanceExistance?.minBalance,
                    amountUpdateClosure: { newAmount in
                        currentInputAmount = newAmount
                    }
                ),
                chainAsset: chainAsset,
                locale: selectedLocale
            )
        ]

        DataValidationRunner(
            validators: baseValidators + setupValidators
        ).runValidation { [weak self] in
            guard let amount = currentInputAmount else {
                return
            }
            self?.wireframe?.showConfirm(from: self?.view, amount: amount)
        }
    }
}
