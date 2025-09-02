import Foundation
import Foundation_iOS

extension InputViewModel {
    static func createAccountInputViewModel(
        for value: String,
        title: String = "",
        required: Bool = true
    ) -> InputViewModelProtocol {
        let inputHandler = InputHandler(
            value: value,
            required: required,
            predicate: required ? NSPredicate.notEmpty : nil,
            processor: TrimmingCharacterProcessor(charset: CharacterSet.whitespacesAndNewlines)
        )

        let viewModel = InputViewModel(inputHandler: inputHandler, title: title)
        return viewModel
    }
}
