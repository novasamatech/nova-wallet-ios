import Foundation
import Foundation_iOS

final class LedgerWalletConfirmPresenter: BaseUsernameSetupPresenter, UsernameSetupPresenterProtocol {
    let wireframe: LedgerWalletConfirmWireframeProtocol
    let interactor: LedgerWalletConfirmInteractorInputProtocol

    let logger: LoggerProtocol
    let localizationManager: LocalizationManagerProtocol

    init(
        interactor: LedgerWalletConfirmInteractorInputProtocol,
        wireframe: LedgerWalletConfirmWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
        self.localizationManager = localizationManager
    }

    func proceed() {
        guard viewModel.inputHandler.completed else {
            return
        }

        let walletNickname = viewModel.inputHandler.value
        interactor.save(with: walletNickname)
    }
}

extension LedgerWalletConfirmPresenter: LedgerWalletConfirmInteractorOutputProtocol {
    func didCreateWallet() {
        wireframe.complete(on: view)
    }

    func didReceive(error: Error) {
        _ = wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale)

        logger.error("Did receive error: \(error)")
    }
}
