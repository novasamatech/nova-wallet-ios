import Foundation

protocol IdentityPresentable: EmailPresentable, WebPresentable, AlertPresentable {
    func presentIdentityItem(
        from view: ControllerBackedProtocol,
        tag: ValidatorInfoViewModel.IdentityTag,
        value: String,
        locale: Locale
    )
}

extension IdentityPresentable {
    func presentIdentityItem(
        from view: ControllerBackedProtocol,
        tag: ValidatorInfoViewModel.IdentityTag,
        value: String,
        locale: Locale
    ) {
        switch tag {
        case .email:
            activateEmail(from: view, email: value, locale: locale)
        case .web:
            if let url = URL(string: value) {
                showUrl(url, from: view)
            }
        case .riot:
            if let url = URL.riotAddress(for: value) {
                showUrl(url, from: view)
            }
        case .twitter:
            if let url = URL.twitterAddress(for: value) {
                showUrl(url, from: view)
            }
        }
    }

    private func activateEmail(from view: ControllerBackedProtocol, email: String, locale: Locale) {
        let message = SocialMessage(
            body: nil,
            subject: "",
            recepients: [email]
        )

        if !writeEmail(with: message, from: view, completionHandler: nil) {
            present(
                message: R.string(preferredLanguages: locale.rLanguages).localizable.noEmailBoundErrorMessage(),
                title: R.string(preferredLanguages: locale.rLanguages).localizable.commonErrorGeneralTitle(),
                closeAction: R.string(preferredLanguages: locale.rLanguages).localizable.commonClose(),
                from: view
            )
        }
    }

    private func showUrl(_ url: URL, from view: ControllerBackedProtocol) {
        showWeb(url: url, from: view, style: .automatic)
    }
}
