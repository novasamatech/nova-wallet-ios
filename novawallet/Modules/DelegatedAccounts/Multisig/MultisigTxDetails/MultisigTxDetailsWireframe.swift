import Foundation

final class MultisigTxDetailsWireframe: MultisigTxDetailsWireframeProtocol {
    func presentCallHashActions(
        from view: ControllerBackedProtocol?,
        value: String,
        locale: Locale
    ) {
        let copyTitle = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.multisigCallHashCopy()

        let shareTitle = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.multisigCallHashShare()

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
        let copyTitle = R.string(preferredLanguages: locale.rLanguages).localizable.multisigCallDataCopy()
        let shareTitle = R.string(preferredLanguages: locale.rLanguages).localizable.multisigCallDataShare()

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
        let title = value.mediumTruncated

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
            closeAction: R.string(preferredLanguages: locale.rLanguages).localizable.commonCancel()
        )

        present(viewModel: viewModel, style: .actionSheet, from: view)
    }
}
