import Foundation
import SoraFoundation

final class UsernameSetupPresenter: UsernameSetupInteractorOutputProtocol {
    weak var view: UsernameSetupViewProtocol?
    var wireframe: UsernameSetupWireframeProtocol!
    var interactor: UsernameSetupInteractorInputProtocol!

    private var viewModel: InputViewModelProtocol = {
        let inputHandling = InputHandler(
            predicate: NSPredicate.notEmpty,
            processor: ByteLengthProcessor.username
        )
        return InputViewModel(inputHandler: inputHandling)
    }()
}

extension UsernameSetupPresenter: UsernameSetupPresenterProtocol {
    func setup() {
        view?.setInput(viewModel: viewModel)
        interactor.setup()
    }

    func proceed() {
        let walletName = viewModel.inputHandler.value
        wireframe.proceed(from: view, walletName: walletName)
    }
}

extension UsernameSetupPresenter: Localizable {
    func applyLocalization() {}
}
