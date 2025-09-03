import Foundation
import BigInt

protocol NominationPoolBondMoreSetupViewProtocol: NominationPoolBondMoreBaseViewProtocol {
    func didReceiveInput(viewModel: AmountInputViewModelProtocol)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveTransferable(viewModel: String?)
    func didReceiveAssetBalance(viewModel: AssetBalanceViewModelProtocol)
}

protocol NominationPoolBondMoreSetupPresenterProtocol: AnyObject {
    func setup()
    func selectAmountPercentage(_ percentage: Float)
    func updateAmount(_ newValue: Decimal?)
    func proceed()
}

protocol NominationPoolBondMoreSetupInteractorInputProtocol: NominationPoolBondMoreBaseInteractorInputProtocol {}

protocol NominationPoolBondMoreSetupInteractorOutputProtocol: NominationPoolBondMoreBaseInteractorOutputProtocol {}

protocol NominationPoolBondMoreSetupWireframeProtocol: NominationPoolBondMoreBaseWireframeProtocol {
    func showConfirm(from view: ControllerBackedProtocol?, amount: Decimal)
}
