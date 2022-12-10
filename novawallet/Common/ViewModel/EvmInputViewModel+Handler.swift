import Foundation
import SoraFoundation

extension InputViewModel {
    static func createTokenSymbolInputViewModel(for value: String, required: Bool = true) -> InputViewModelProtocol {
        let inputHandling = InputHandler(
            value: value,
            required: required,
            maxLength: 12,
            predicate: required ? NSPredicate.notEmpty : nil,
            processor: TrimmingCharacterProcessor(charset: .whitespaces)
        )

        return InputViewModel(inputHandler: inputHandling)
    }

    static func createTokenDecimalsInputViewModel(for value: String, required: Bool = true) -> InputViewModelProtocol {
        let inputHandling = InputHandler(
            value: value,
            required: required,
            maxLength: 3,
            validCharacterSet: CharacterSet.decimalDigits,
            predicate: required ? NSPredicate.notEmpty : nil,
            processor: TrimmingCharacterProcessor(charset: .whitespaces)
        )

        return InputViewModel(inputHandler: inputHandling)
    }

    static func createTokenPriceIdInputViewModel(for value: String, required: Bool = true) -> InputViewModelProtocol {
        let inputHandling = InputHandler(
            value: value,
            required: required,
            maxLength: 116,
            predicate: required ? NSPredicate.notEmpty : nil,
            processor: TrimmingCharacterProcessor(charset: .whitespaces)
        )

        return InputViewModel(inputHandler: inputHandling)
    }
}
