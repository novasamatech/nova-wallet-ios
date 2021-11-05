import Foundation
import CommonWallet
import SoraFoundation
import SubstrateSdk
import SoraKeystore

final class ReceiveViewFactory: ReceiveViewFactoryProtocol {
    let accountViewModel: ReceiveAccountViewModelProtocol
    let chainFormat: ChainFormat
    let localizationManager: LocalizationManagerProtocol

    weak var commandFactory: WalletCommandFactoryProtocol?

    private lazy var iconGenerator = PolkadotIconGenerator()

    init(
        accountViewModel: ReceiveAccountViewModelProtocol,
        chainFormat: ChainFormat,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.accountViewModel = accountViewModel
        self.chainFormat = chainFormat
        self.localizationManager = localizationManager
    }

    func createHeaderView() -> UIView? {
        let address = accountViewModel.address
        guard let accountId = try? address.toAccountId(using: chainFormat) else {
            return nil
        }

        let username = accountViewModel.displayName

        let icon = try? iconGenerator.generateFromAccountId(accountId)
            .imageWithFillColor(
                R.color.colorWhite()!,
                size: CGSize(width: 32.0, height: 32.0),
                contentScale: UIScreen.main.scale
            )

        let receiveView = R.nib.receiveHeaderView(owner: nil)
        receiveView?.accountView.title = username
        receiveView?.accountView.subtitle = address
        receiveView?.accountView.iconImage = icon
        receiveView?.accountView.subtitleLabel?.lineBreakMode = .byTruncatingMiddle

        let locale = localizationManager.selectedLocale

        if let commandFactory = commandFactory {
            // TODO: Fix account presentation
            let command = WalletAccountOpenCommand(
                address: address,
                chain: Chain.westend,
                commandFactory: commandFactory,
                locale: locale
            )
            receiveView?.actionCommand = command
        }

        let infoTitle = R.string.localizable
            .walletReceiveDescription(preferredLanguages: locale.rLanguages)
        receiveView?.infoLabel.text = infoTitle

        return receiveView
    }
}
