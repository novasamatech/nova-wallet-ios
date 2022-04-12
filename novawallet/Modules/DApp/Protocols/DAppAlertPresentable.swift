import Foundation
import UIKit

protocol DAppAlertPresentable: AlertPresentable {
    func showFavoritesRemovalConfirmation(
        from view: ControllerBackedProtocol?,
        name: String,
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
        let title = R.string.localizable.dappRemoveFavoritesTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.dappRemoveFavoritesMessage(
            name,
            preferredLanguages: locale.rLanguages
        )

        let removeTitle = R.string.localizable.commonRemove(preferredLanguages: locale.rLanguages)

        let removeAction = AlertPresentableAction(title: removeTitle, style: .destructive, handler: handler)

        let closeTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [removeAction],
            closeAction: closeTitle
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }
}
