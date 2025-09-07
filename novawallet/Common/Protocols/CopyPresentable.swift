import Foundation
import Foundation_iOS
import UIKit

protocol CopyPresentable {
    func presentCopy(
        from view: ControllerBackedProtocol,
        value: String,
        locale: Locale
    )
}

extension CopyPresentable where Self: AlertPresentable {
    func copyValue(
        from view: ControllerBackedProtocol?,
        value: String,
        locale: Locale
    ) {
        UIPasteboard.general.string = value

        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonCopied()
        let controller = ModalAlertFactory.createSuccessAlert(title)

        view?.controller.present(
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
        let copyTitle = R.string(preferredLanguages: locale.rLanguages).localizable.commonCopy()

        let title = value.twoLineString(with: 16)

        let action = AlertPresentableAction(
            title: copyTitle,
            style: .normal
        ) { [weak self] in
            self?.copyValue(from: view, value: value, locale: locale)
        }

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: nil,
            actions: [action],
            closeAction: R.string(preferredLanguages: locale.rLanguages).localizable.commonCancel()
        )

        present(viewModel: viewModel, style: .actionSheet, from: view)
    }
}
