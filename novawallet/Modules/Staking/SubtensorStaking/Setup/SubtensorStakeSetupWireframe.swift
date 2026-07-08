import UIKit

/// Routing for the new Subtensor stake setup flow.
///
/// `showValidatorPicker` pushes a `SubtensorValidatorPickerViewController`
/// onto the current navigation stack so the picker behaves like the
/// Polkadot validator-list flow (back arrow, no modal sheet). The picker
/// pops itself once a validator is tapped.
final class SubtensorStakeSetupWireframe: SubtensorStakeSetupWireframeProtocol {
    func showValidatorPicker(
        from view: SubtensorStakeSetupViewProtocol?,
        netuid: UInt16,
        prefetched: [SubtensorValidator],
        validatorProvider: SubtensorValidatorProvider,
        cellViewModelFactory: SubtensorValidatorCellViewModelFactory,
        onSelected: @escaping (SubtensorValidator) -> Void
    ) {
        let picker = SubtensorValidatorPickerViewController(
            netuid: netuid,
            validatorProvider: validatorProvider,
            cellViewModelFactory: cellViewModelFactory,
            prefetched: prefetched,
            onSelection: onSelected
        )

        view?.controller.navigationController?.pushViewController(picker, animated: true)
    }

    func showError(from view: SubtensorStakeSetupViewProtocol?, message: String) {
        // TODO(phase-e): R.string.localizable.commonErrorGeneralTitle(...)
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        view?.controller.present(alert, animated: true)
    }

    func showConfirm(
        from view: SubtensorStakeSetupViewProtocol?,
        chainAsset: ChainAsset,
        validator: SubtensorValidator,
        amount: Decimal
    ) {
        guard let confirmView = SubtensorStakeConfirmViewFactory.createView(
            chainAsset: chainAsset,
            validator: validator,
            amount: amount
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }
}
