import Foundation
import Foundation_iOS

final class ParitySignerAddConfirmPresenter: BaseUsernameSetupPresenter, UsernameSetupPresenterProtocol {
    let wireframe: ParitySignerAddConfirmWireframeProtocol
    let interactor: ParitySignerAddConfirmInteractorInputProtocol

    let logger: LoggerProtocol
    let localizationManager: LocalizationManagerProtocol

    init(
        interactor: ParitySignerAddConfirmInteractorInputProtocol,
        wireframe: ParitySignerAddConfirmWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
        self.logger = logger
    }

    func proceed() {
        guard viewModel.inputHandler.completed else {
            return
        }

        let walletNickname = viewModel.inputHandler.value
        interactor.save(with: walletNickname)
    }
}

extension ParitySignerAddConfirmPresenter: ParitySignerAddConfirmInteractorOutputProtocol {
    func didCreateWallet() {
        wireframe.complete(on: view)
    }

    func didReceive(error: Error) {
        _ = wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale)

        logger.error("Did receive error: \(error)")
    }
}
