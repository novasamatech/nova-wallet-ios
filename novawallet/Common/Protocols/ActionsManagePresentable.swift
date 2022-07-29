import Foundation
import SoraFoundation
import SoraUI

protocol ActionsManagePresentable {
    func presentActionsManage(
        from view: ControllerBackedProtocol,
        actions: [LocalizableResource<ActionManageViewModel>],
        title: LocalizableResource<String>,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    )
}

extension ActionsManagePresentable {
    func presentActionsManage(
        from view: ControllerBackedProtocol,
        actions: [LocalizableResource<ActionManageViewModel>],
        title: LocalizableResource<String>,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) {
        guard let picker = ModalPickerFactory.createActionsList(
            title: title,
            actions: actions,
            delegate: delegate,
            context: context
        ) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)

        picker.modalTransitioningFactory = factory
        picker.modalPresentationStyle = .custom

        view.controller.present(picker, animated: true)
    }
}
