import Foundation

final class MultisigTxDetailsWireframe: MultisigTxDetailsWireframeProtocol {
    func presentCallHashActions(
        from view: ControllerBackedProtocol?,
        value: String,
        locale: Locale
    ) {
        let copyTitle = R.string.localizable.multisigCallHashCopy(preferredLanguages: locale.rLanguages)
        let shareTitle = R.string.localizable.multisigCallHashShare(preferredLanguages: locale.rLanguages)

        presentCopyShare(
            from: view,
            value: value,
            copyTitle: copyTitle,
            shareTitle: shareTitle,
            locale: locale
        )
    }

    func presentCallDataActions(
        from view: ControllerBackedProtocol?,
        value: String,
        locale: Locale
    ) {
        let copyTitle = R.string.localizable.multisigCallDataCopy(preferredLanguages: locale.rLanguages)
        let shareTitle = R.string.localizable.multisigCallDataShare(preferredLanguages: locale.rLanguages)

        presentCopyShare(
            from: view,
            value: value,
            copyTitle: copyTitle,
            shareTitle: shareTitle,
            locale: locale
        )
    }
}

// MARK: - Private

private extension MultisigTxDetailsWireframe {
    func presentCopyShare(
        from view: ControllerBackedProtocol?,
        value: String,
        copyTitle: String,
        shareTitle: String,
        locale: Locale
    ) {
        let title = value.truncatedMiddle(limit: 20)

        let copyAction = AlertPresentableAction(
            title: copyTitle,
            style: .normal
        ) { [weak self] in
            self?.copyValue(from: view, value: value, locale: locale)
        }

        let shareAction = AlertPresentableAction(
            title: shareTitle,
            style: .normal
        ) { [weak self] in
            self?.share(items: [value], from: view, with: nil)
        }

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: nil,
            actions: [copyAction, shareAction],
            closeAction: R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        )

        present(viewModel: viewModel, style: .actionSheet, from: view)
    }
}
