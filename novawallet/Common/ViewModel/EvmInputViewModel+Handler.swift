import Foundation
import Foundation_iOS

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

        let viewModel = InputViewModel(inputHandler: inputHandler, placeholder: "0x...")
        return viewModel
    }

    static func createTokenSymbolInputViewModel(for value: String, required: Bool = true) -> InputViewModelProtocol {
        let inputHandling = InputHandler(
            value: value,
            required: required,
            maxLength: 11,
            predicate: required ? NSPredicate.notEmpty : nil,
            processor: TrimmingCharacterProcessor(charset: .whitespaces)
        )

        return InputViewModel(inputHandler: inputHandling, placeholder: "USDT")
    }

    static func createTokenDecimalsInputViewModel(for value: String, required: Bool = true) -> InputViewModelProtocol {
        let inputHandling = InputHandler(
            value: value,
            required: required,
            maxLength: 2,
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

    static func createNotEmptyInputViewModel(
        for value: String,
        enabled: Bool = true,
        required: Bool = true,
        placeholder: String? = nil,
        spacesAllowed: Bool = false
    ) -> InputViewModelProtocol {
        let inputHandling = InputHandler(
            value: value,
            required: required,
            enabled: enabled,
            predicate: required ? NSPredicate.notEmpty : nil,
            processor: spacesAllowed
                ? nil
                : TrimmingCharacterProcessor(charset: .whitespaces)
        )

        return InputViewModel(
            inputHandler: inputHandling,
            placeholder: placeholder ?? ""
        )
    }
}
