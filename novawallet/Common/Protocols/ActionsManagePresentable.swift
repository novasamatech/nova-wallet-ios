import Foundation
import Foundation_iOS
import UIKit_iOS
import UIKit

protocol ActionsManagePresentable {
    func presentActionsManage(
        from view: ControllerBackedProtocol,
        actions: [LocalizableResource<ActionManageViewModel>],
        title: LocalizableResource<String>?,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    )
}

extension ActionsManagePresentable {
    func presentActionsManage(
        from view: ControllerBackedProtocol,
        actions: [LocalizableResource<ActionManageViewModel>],
        title: LocalizableResource<String>?,
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

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        picker.modalTransitioningFactory = factory
        picker.modalPresentationStyle = .custom

        view.controller.present(picker, animated: true)
    }
}
