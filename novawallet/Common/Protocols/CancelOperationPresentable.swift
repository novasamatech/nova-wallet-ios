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
            title: R.string.localizable.commonCancelOperationAction(preferredLanguages: locale.rLanguages),
            style: .destructive
        ) {
            destructiveClosure()
        }

        let viewModel = AlertPresentableViewModel(
            title: R.string.localizable.commonCancelOperationMessage(preferredLanguages: locale.rLanguages),
            message: nil,
            actions: [action],
            closeAction: R.string.localizable.commonKeepEditingAction(preferredLanguages: locale.rLanguages)
        )

        present(viewModel: viewModel, style: .actionSheet, from: view)
    }
}
