import Foundation
import UIKit
import BigInt

/// VIPER protocols for the Subtensor stake setup flow.
///
/// The view-layer shape matches `CollatorStakingSetupViewProtocol` so
/// Subtensor re-uses Nova's canonical setup-screen binding idiom
/// (`AssetBalanceViewModelProtocol`, `BalanceViewModelProtocol`, the
/// `AccountDetailsSelectionViewModel` for the selector row, etc.).

protocol SubtensorStakeSetupViewProtocol: ControllerBackedProtocol {
    func didReceiveValidator(viewModel: AccountDetailsSelectionViewModel?)
    func didReceiveAssetBalance(viewModel: AssetBalanceViewModelProtocol)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveMinStake(viewModel: BalanceViewModelProtocol?)
    func didReceiveNovaFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveNovaFeeDisclaimer(visible: Bool)
}

protocol SubtensorStakeSetupPresenterProtocol: AnyObject {
    var netuid: UInt16 { get }
    func setup()
    func selectValidator()
    func updateAmount(_ newValue: Decimal?)
    func selectAmountPercentage(_ percentage: Float)
    func proceed()
}

protocol SubtensorStakeSetupInteractorInputProtocol: AnyObject {
    func setup()
    func refreshValidators()
    /// Re-estimate the add_stake_limit fee with the user's selected validator
    /// and typed amount. Pass nil to use placeholder (zero hotkey + 1 TAO).
    func estimateFee(hotkey: AccountId?, amount: BigUInt?)
}

protocol SubtensorStakeSetupInteractorOutputProtocol: AnyObject {
    func didReceive(validators: [SubtensorValidator])
    func didReceive(minDelegation: BigUInt)
    func didReceive(assetBalance: AssetBalance?)
    func didReceive(price: PriceData?)
    func didReceive(fee: ExtrinsicFeeProtocol?)
    func didReceive(error: Error)
}

protocol SubtensorStakeSetupWireframeProtocol: AnyObject {
    func showValidatorPicker(
        from view: SubtensorStakeSetupViewProtocol?,
        netuid: UInt16,
        prefetched: [SubtensorValidator],
        validatorProvider: SubtensorValidatorProvider,
        cellViewModelFactory: SubtensorValidatorCellViewModelFactory,
        onSelected: @escaping (SubtensorValidator) -> Void
    )

    func showError(from view: SubtensorStakeSetupViewProtocol?, message: String)

    func showConfirm(
        from view: SubtensorStakeSetupViewProtocol?,
        chainAsset: ChainAsset,
        validator: SubtensorValidator,
        amount: Decimal
    )
}
