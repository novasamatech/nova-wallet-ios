import Foundation
import UIKit
import BigInt

protocol SubtensorUnstakeSetupViewProtocol: ControllerBackedProtocol {
    func didReceiveValidator(viewModel: AccountDetailsSelectionViewModel)
    func didReceivePosition(viewModel: BalanceViewModelProtocol)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAssetBalance(viewModel: AssetBalanceViewModelProtocol)
    func didReceiveNovaFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveNovaFeeDisclaimer(visible: Bool)
}

protocol SubtensorUnstakeSetupPresenterProtocol: AnyObject {
    func setup()
    func updateAmount(_ newValue: Decimal?)
    func selectAmountPercentage(_ percentage: Float)
    func proceed()
}

protocol SubtensorUnstakeSetupInteractorInputProtocol: AnyObject {
    func setup()
}

protocol SubtensorUnstakeSetupInteractorOutputProtocol: AnyObject {
    func didReceive(price: PriceData?)
    func didReceive(fee: ExtrinsicFeeProtocol?)
    func didReceive(error: Error)
}

protocol SubtensorUnstakeSetupWireframeProtocol: AnyObject {
    func showConfirm(
        from view: SubtensorUnstakeSetupViewProtocol?,
        chainAsset: ChainAsset,
        position: SubtensorStakePosition,
        amount: Decimal
    )

    func showError(from view: SubtensorUnstakeSetupViewProtocol?, message: String)
}
