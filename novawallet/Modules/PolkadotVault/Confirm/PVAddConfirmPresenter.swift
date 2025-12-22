import Foundation
import Foundation_iOS

final class PVAddConfirmPresenter: BaseUsernameSetupPresenter, UsernameSetupPresenterProtocol {
    let wireframe: PVAddConfirmWireframeProtocol
    let interactor: PVAddConfirmInteractorInputProtocol

    let logger: LoggerProtocol
    let localizationManager: LocalizationManagerProtocol

    init(
        interactor: PVAddConfirmInteractorInputProtocol,
        wireframe: PVAddConfirmWireframeProtocol,
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

extension PVAddConfirmPresenter: PVAddConfirmInteractorOutputProtocol {
    func didCreateWallet() {
        wireframe.complete(on: view)
    }

    func didReceive(error: Error) {
        _ = wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale)

        logger.error("Did receive error: \(error)")
    }
}
