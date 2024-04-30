import Foundation
import SoraFoundation

final class ImportCloudPasswordPresenter {
    weak var view: ImportCloudPasswordViewProtocol?
    let wireframe: ImportCloudPasswordWireframeProtocol
    let interactor: ImportCloudPasswordInteractorInputProtocol
    let localizationManager: LocalizationManagerProtocol
    let logger: LoggerProtocol

    private let viewModel = InputViewModel(
        inputHandler: InputHandler(predicate: NSPredicate.notEmpty)
    )

    init(
        interactor: ImportCloudPasswordInteractorInputProtocol,
        wireframe: ImportCloudPasswordWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

extension ImportCloudPasswordPresenter: ImportCloudPasswordPresenterProtocol {
    func setup() {
        view?.didReceive(passwordViewModel: viewModel)
    }

    func activateForgotPassword() {}

    func activateContinue() {}
}

extension ImportCloudPasswordPresenter: ImportCloudPasswordInteractorOutputProtocol {}
