import Foundation
import Foundation_iOS

protocol StakingRebondSetupViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceiveInput(viewModel: LocalizableResource<AmountInputViewModelProtocol>)
    func didReceiveTransferable(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol StakingRebondSetupPresenterProtocol: AnyObject {
    func setup()
    func selectAmountPercentage(_ percentage: Float)
    func updateAmount(_ newValue: Decimal)
    func proceed()
    func close()
}

protocol StakingRebondSetupInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee()
}

protocol StakingRebondSetupInteractorOutputProtocol: AnyObject {
    func didReceiveStakingLedger(result: Result<Staking.Ledger?, Error>)
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveController(result: Result<ChainAccountResponse?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveAccountBalance(result: Result<AssetBalance?, Error>)
}

protocol StakingRebondSetupWireframeProtocol: AlertPresentable, ErrorPresentable,
    StakingErrorPresentable {
    func proceed(view _: StakingRebondSetupViewProtocol?, amount _: Decimal)
    func close(view: StakingRebondSetupViewProtocol?)
}
