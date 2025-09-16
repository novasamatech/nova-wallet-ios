import Foundation
import UIKit

protocol DAppAlertPresentable: AlertPresentable {
    func showFavoritesRemovalConfirmation(
        from view: ControllerBackedProtocol?,
        name: String,
        locale: Locale,
        handler: @escaping () -> Void
    )

    func showAuthorizedRemovalConfirmation(
        from view: ControllerBackedProtocol?,
        name: String,
        locale: Locale,
        handler: @escaping () -> Void
    )

    func showUnknownDappWarning(
        from view: ControllerBackedProtocol?,
        email: String,
        locale: Locale,
        handler: @escaping () -> Void
    )
}

extension DAppAlertPresentable {
    func showFavoritesRemovalConfirmation(
        from view: ControllerBackedProtocol?,
        name: String,
        locale: Locale,
        handler: @escaping () -> Void
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.dappRemoveFavoritesTitle()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.dappRemoveFavoritesMessage(name)

        showRemoval(from: view, title: title, message: message, locale: locale, handler: handler)
    }

    func showAuthorizedRemovalConfirmation(
        from view: ControllerBackedProtocol?,
        name: String,
        locale: Locale,
        handler: @escaping () -> Void
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.dappRemoveAuthorizedTitle()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.dappRemoveAuthorizedMessage(name)

        showRemoval(from: view, title: title, message: message, locale: locale, handler: handler)
    }

    func showUnknownDappWarning(
        from view: ControllerBackedProtocol?,
        email: String,
        locale: Locale,
        handler: @escaping () -> Void
    ) {
        let action = AlertPresentableAction(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.dappUnknownWarningOpen(),
            style: .destructive,
            handler: handler
        )
        let viewModel = AlertPresentableViewModel(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.dappUnknownWarningTitle(),
            message: R.string(preferredLanguages: locale.rLanguages).localizable.dappUnknownWarningMessage(email),
            actions: [action],
            closeAction: R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()
        )

        present(
            viewModel: viewModel,
            style: .alert,
            from: view
        )
    }

    private func showRemoval(
        from view: ControllerBackedProtocol?,
        title: String,
        message: String,
        locale: Locale,
        handler: @escaping () -> Void
    ) {
        let removeTitle = R.string(preferredLanguages: locale.rLanguages).localizable.commonRemove()

        let removeAction = AlertPresentableAction(title: removeTitle, style: .destructive, handler: handler)

        let closeTitle = R.string(preferredLanguages: locale.rLanguages).localizable.commonCancel()

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [removeAction],
            closeAction: closeTitle
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }
}
