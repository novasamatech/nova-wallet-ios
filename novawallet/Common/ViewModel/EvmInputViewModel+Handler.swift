import Foundation
import SoraFoundation

extension InputViewModel {
    static func createContractAddressViewModel(
        for value: String,
        required: Bool = true
    ) -> InputViewModelProtocol {
        let inputHandler = InputHandler(
            value: value,
            required: required,
            maxLength: 42,
            predicate: required ? NSPredicate.notEmpty : nil,
            processor: TrimmingCharacterProcessor(charset: CharacterSet.whitespacesAndNewlines)
        )

        let viewModel = InputViewModel(inputHandler: inputHandler, placeholder: "0x..")
        return viewModel
    }

    static func createTokenSymbolInputViewModel(for value: String, required: Bool = true) -> InputViewModelProtocol {
        let inputHandling = InputHandler(
            value: value,
            required: required,
            maxLength: 12,
            predicate: required ? NSPredicate.notEmpty : nil,
            processor: TrimmingCharacterProcessor(charset: .whitespaces)
        )

        return InputViewModel(inputHandler: inputHandling, placeholder: "USDT")
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

        return InputViewModel(inputHandler: inputHandling, placeholder: "18")
    }

    static func createTokenPriceIdInputViewModel(
        for value: String,
        required: Bool = true,
        placeholder: String? = nil
    ) -> InputViewModelProtocol {
        let inputHandling = InputHandler(
            value: value,
            required: required,
            maxLength: 116,
            predicate: required ? NSPredicate.notEmpty : nil,
            processor: TrimmingCharacterProcessor(charset: .whitespaces)
        )

        return InputViewModel(inputHandler: inputHandling, placeholder: placeholder ?? "")
    }
}
