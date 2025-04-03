import Foundation
import Foundation_iOS

class BaseUsernameSetupPresenter {
    weak var view: UsernameSetupViewProtocol?

    let viewModel: InputViewModelProtocol = {
        let inputHandling = InputHandler(
            predicate: NSPredicate.notEmpty,
            processor: ByteLengthProcessor.username
        )
        return InputViewModel(inputHandler: inputHandling)
    }()

    func setup() {
        view?.setInput(viewModel: viewModel)
    }
}
