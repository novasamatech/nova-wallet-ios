import Foundation
import CommonWallet
import RobinHood

final class WalletExtrinsicOpenCommand: WalletCommandProtocol {
    let extrinsicHash: String
    let locale: Locale
    let explorers: [ChainModel.Explorer]?

    weak var commandFactory: WalletCommandFactoryProtocol?

    init(
        extrinsicHash: String,
        explorers: [ChainModel.Explorer]?,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) {
        self.extrinsicHash = extrinsicHash
        self.explorers = explorers
        self.commandFactory = commandFactory
        self.locale = locale
    }

    func execute() throws {
        let title = R.string.localizable
            .transactionDetailsHashTitle(preferredLanguages: locale.rLanguages)
        let alertController = UIAlertController(
            title: title,
            message: nil,
            preferredStyle: .actionSheet
        )

        let copyTitle = R.string.localizable
            .transactionDetailsCopyHash(preferredLanguages: locale.rLanguages)

        let copy = UIAlertAction(title: copyTitle, style: .default) { [weak self] _ in
            self?.copyHash()
        }

        alertController.addAction(copy)

        let actions: [UIAlertAction] = explorers?.compactMap { explorer in
            guard
                let urlTemplate = explorer.extrinsic,
                let url = try? EndpointBuilder(urlTemplate: urlTemplate)
                .buildParameterURL(extrinsicHash) else {
                return nil
            }

            return UIAlertAction(title: explorer.name, style: .default) { [weak self] _ in
                self?.present(url: url)
            }
        } ?? []

        actions.forEach { alertController.addAction($0) }

        let cancelTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale.rLanguages)
        let cancel = UIAlertAction(title: cancelTitle, style: .cancel, handler: nil)

        alertController.addAction(cancel)

        let command = commandFactory?.preparePresentationCommand(for: alertController)
        command?.presentationStyle = .modal(inNavigation: false)
        try command?.execute()
    }

    private func copyHash() {
        UIPasteboard.general.string = extrinsicHash

        let title = R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages)
        let controller = ModalAlertFactory.createSuccessAlert(title)

        let command = commandFactory?.preparePresentationCommand(for: controller)
        command?.presentationStyle = .modal(inNavigation: false)
        try? command?.execute()
    }

    private func present(url: URL) {
        let webController = WebViewFactory.createWebViewController(for: url, style: .automatic)
        let command = commandFactory?.preparePresentationCommand(for: webController)
        command?.presentationStyle = .modal(inNavigation: false)
        try? command?.execute()
    }
}
