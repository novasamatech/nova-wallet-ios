import Foundation

extension CloudBackup {
    struct PasswordValidationResult: OptionSet {
        static let minLength = 8

        typealias RawValue = UInt8

        static let minChars = PasswordValidationResult(rawValue: 1 << 0)
        static let asciiChars = PasswordValidationResult(rawValue: 1 << 1)
        static let digits = PasswordValidationResult(rawValue: 1 << 2)
        static let confirmMatchesPassword = PasswordValidationResult(rawValue: 1 << 3)
        static let all: PasswordValidationResult = [.minChars, asciiChars, .digits, confirmMatchesPassword]

        let rawValue: UInt8

        init(rawValue: RawValue) {
            self.rawValue = rawValue
        }
    }
}
