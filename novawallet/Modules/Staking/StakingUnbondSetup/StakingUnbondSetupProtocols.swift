import Foundation
import Foundation_iOS
import BigInt

protocol StakingUnbondSetupViewProtocol: ControllerBackedProtocol {
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceiveInput(viewModel: LocalizableResource<AmountInputViewModelProtocol>)
    func didReceiveTransferable(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceiveBonding(duration: LocalizableResource<String>)
}

protocol StakingUnbondSetupPresenterProtocol: AnyObject {
    func setup()
    func selectAmountPercentage(_ percentage: Float)
    func updateAmount(_ newValue: Decimal)
    func proceed()
    func close()
}

protocol StakingUnbondSetupInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee()
}

protocol StakingUnbondSetupInteractorOutputProtocol: AnyObject {
    func didReceiveStakingLedger(result: Result<Staking.Ledger?, Error>)
    func didReceiveAccountBalance(result: Result<AssetBalance?, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>)
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>)
    func didReceiveController(result: Result<ChainAccountResponse?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveStakingDuration(result: Result<StakingDuration, Error>)
}

protocol StakingUnbondSetupWireframeProtocol: AlertPresentable, ErrorPresentable,
    StakingErrorPresentable {
    func close(view: StakingUnbondSetupViewProtocol?)
    func proceed(view: StakingUnbondSetupViewProtocol?, amount: Decimal)
}
