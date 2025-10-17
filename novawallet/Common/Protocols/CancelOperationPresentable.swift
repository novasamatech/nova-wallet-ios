import Foundation

protocol CancelOperationPresentable: AnyObject {
    func presentCancelOperation(
        from view: ControllerBackedProtocol,
        locale: Locale,
        destructiveClosure: @escaping () -> Void
    )
}

extension CancelOperationPresentable where Self: AlertPresentable {
    func presentCancelOperation(
        from view: ControllerBackedProtocol,
        locale: Locale,
        destructiveClosure: @escaping () -> Void
    ) {
        let action = AlertPresentableAction(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.commonCancelOperationAction(),
            style: .destructive
        ) {
            destructiveClosure()
        }

        let viewModel = AlertPresentableViewModel(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.commonCancelOperationMessage(),
            message: nil,
            actions: [action],
            closeAction: R.string(preferredLanguages: locale.rLanguages).localizable.commonKeepEditingAction()
        )

        present(viewModel: viewModel, style: .actionSheet, from: view)
    }
}
