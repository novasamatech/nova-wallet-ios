import Foundation
import Foundation_iOS
import Operation_iOS
import BigInt

protocol StakingBondMoreViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceiveInput(viewModel: LocalizableResource<AmountInputViewModelProtocol>)
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol StakingBondMorePresenterProtocol: AnyObject {
    func setup()
    func handleContinueAction()
    func updateAmount(_ newValue: Decimal)
    func selectAmountPercentage(_ percentage: Float)
}

protocol StakingBondMoreInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee()
}

protocol StakingBondMoreInteractorOutputProtocol: AnyObject {
    func didReceiveAccountBalance(result: Result<AssetBalance?, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>)
    func didReceiveStash(result: Result<ChainAccountResponse?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>)
    func didReceiveStakingMigratedToHold(result: Result<Bool, Error>)
}

protocol StakingBondMoreWireframeProtocol: AlertPresentable, ErrorPresentable, StakingErrorPresentable {
    func showConfirmation(from view: ControllerBackedProtocol?, amount: Decimal)
    func close(view: ControllerBackedProtocol?)
}
