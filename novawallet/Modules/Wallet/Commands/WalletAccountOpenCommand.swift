import Foundation
import CommonWallet

final class WalletAccountOpenCommand: WalletCommandProtocol {
    let address: String
    let locale: Locale
    let chain: ChainModel

    weak var commandFactory: WalletCommandFactoryProtocol?

    init(
        address: String,
        chain: ChainModel,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) {
        self.address = address
        self.chain = chain
        self.commandFactory = commandFactory
        self.locale = locale
    }

    func execute() throws {
        guard let controller = AddressOptionsPresentableFactory.createAccountOptionsController(
            address: address,
            chain: chain,
            copyClosure: copyAddress,
            urlClosure: present(url:)
        ) else {
            return
        }

        let command = commandFactory?.preparePresentationCommand(for: controller)
        command?.presentationStyle = .modal(inNavigation: false)
        try command?.execute()
    }

    private func copyAddress() {
        UIPasteboard.general.string = address

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
