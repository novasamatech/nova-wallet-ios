import Foundation
import SoraFoundation

extension InputViewModel {
    static func createAccountInputViewModel(for value: String) -> InputViewModelProtocol {
        let inputHandler = InputHandler(
            value: value,
            maxLength: 70,
            validCharacterSet: CharacterSet.address,
            predicate: NSPredicate.notEmpty
        )

        let viewModel = InputViewModel(inputHandler: inputHandler)
        return viewModel
    }
}
