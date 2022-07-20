import Foundation
import SoraFoundation

extension InputViewModel {
    static func createAccountInputViewModel(for value: String, required: Bool = true) -> InputViewModelProtocol {
        let inputHandler = InputHandler(
            value: value,
            required: required,
            maxLength: 70,
            validCharacterSet: CharacterSet.address,
            predicate: required ? NSPredicate.notEmpty : nil
        )

        let viewModel = InputViewModel(inputHandler: inputHandler)
        return viewModel
    }
}
