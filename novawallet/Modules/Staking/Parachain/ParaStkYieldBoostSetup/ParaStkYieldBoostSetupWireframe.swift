import Foundation
import SoraFoundation

final class ParaStkYieldBoostSetupWireframe: ParaStkYieldBoostSetupWireframeProtocol {
    func showDelegationSelection(
        from view: ParaStkYieldBoostSetupViewProtocol?,
        viewModels: [AccountDetailsPickerViewModel],
        selectedIndex: Int,
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    ) {
        guard let infoVew = ModalPickerFactory.createCollatorsPickingList(
            viewModels,
            actionViewModel: nil,
            selectedIndex: selectedIndex,
            delegate: delegate,
            context: context
        ) else {
            return
        }

        view?.controller.present(infoVew, animated: true, completion: nil)
    }
}
