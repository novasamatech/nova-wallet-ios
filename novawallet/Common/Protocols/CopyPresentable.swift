import Foundation
import SoraFoundation

protocol CopyPresentable {
    func presentCopy(
        from view: ControllerBackedProtocol,
        value: String,
        locale: Locale
    )
}

extension CopyPresentable where Self: AlertPresentable {
    private func copyAddress(
        from view: ControllerBackedProtocol,
        value: String,
        locale: Locale
    ) {
        UIPasteboard.general.string = value

        let title = R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages)
        let controller = ModalAlertFactory.createSuccessAlert(title)

        view.controller.present(
            controller,
            animated: true,
            completion: nil
        )
    }

    func presentCopy(
        from view: ControllerBackedProtocol,
        value: String,
        locale: Locale
    ) {
        let copyTitle = R.string.localizable.commonCopy(preferredLanguages: locale.rLanguages)

        let title = value.twoLineString(with: 16)

        let action = AlertPresentableAction(
            title: copyTitle,
            style: .normal
        ) { [weak self] in
            self?.copyAddress(from: view, value: value, locale: locale)
        }

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: nil,
            actions: [action],
            closeAction: R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        )

        present(viewModel: viewModel, style: .actionSheet, from: view)
    }
}
