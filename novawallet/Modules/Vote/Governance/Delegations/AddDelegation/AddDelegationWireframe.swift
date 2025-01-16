import Foundation
import Foundation_iOS

final class AddDelegationWireframe: AddDelegationWireframeProtocol {
    let state: GovernanceSharedState

    init(state: GovernanceSharedState) {
        self.state = state
    }

    func showPicker(
        from view: AddDelegationViewProtocol?,
        title: LocalizableResource<String>?,
        items: [LocalizableResource<SelectableTitleTableViewCell.Model>],
        selectedIndex: Int,
        delegate: ModalPickerViewControllerDelegate
    ) {
        guard let pickerView = ModalPickerFactory.createSelectionList(
            title: title,
            items: items,
            selectedIndex: selectedIndex,
            delegate: delegate
        )
        else {
            return
        }

        view?.controller.present(pickerView, animated: true)
    }

    func showInfo(from view: AddDelegationViewProtocol?, delegate: GovernanceDelegateLocal) {
        guard let infoView = GovernanceDelegateInfoViewFactory.createView(for: state, delegate: delegate) else {
            return
        }

        view?.controller.navigationController?.pushViewController(infoView.controller, animated: true)
    }

    func showSearch(
        from view: AddDelegationViewProtocol?,
        initDelegates: [AccountAddress: GovernanceDelegateLocal],
        initDelegations: [AccountAddress: GovernanceYourDelegationGroup]
    ) {
        guard
            let searchView = GovernanceDelegateSearchViewFactory.createView(
                for: state,
                delegates: initDelegates,
                yourDelegations: initDelegations
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(searchView.controller, animated: true)
    }
}
