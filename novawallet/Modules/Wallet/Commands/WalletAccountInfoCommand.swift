import Foundation
import CommonWallet
import SoraFoundation

final class WalletAccountInfoCommand: WalletCommandProtocol {
    weak var commandFactory: WalletCommandFactoryProtocol?

    let balanceContext: BalanceContext
    let amountFormatter: LocalizableResource<TokenFormatter>
    let priceFormatter: LocalizableResource<TokenFormatter>
    let precision: Int16

    init(
        balanceContext: BalanceContext,
        amountFormatter: LocalizableResource<TokenFormatter>,
        priceFormatter: LocalizableResource<TokenFormatter>,
        commandFactory: WalletCommandFactoryProtocol,
        precision: Int16
    ) {
        self.balanceContext = balanceContext
        self.amountFormatter = amountFormatter
        self.priceFormatter = priceFormatter
        self.commandFactory = commandFactory
        self.precision = precision
    }

    func execute() throws {
        let viewController = ModalInfoFactory.createFromBalanceContext(
            balanceContext,
            amountFormatter: amountFormatter,
            priceFormatter: priceFormatter,
            precision: precision
        )

        let presentationCommand = commandFactory?.preparePresentationCommand(for: viewController)
        presentationCommand?.presentationStyle = .modal(inNavigation: false)

        try presentationCommand?.execute()
    }
}
