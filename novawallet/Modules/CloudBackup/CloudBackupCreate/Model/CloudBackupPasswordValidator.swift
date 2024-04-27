import Foundation

protocol CloudBackupPasswordValidating {
    func validate(password: String?, confirmation: String?) -> CloudBackup.PasswordValidationResult
}

extension CloudBackupPasswordValidating {
    func isValid(password: String?, confirmation: String?) -> Bool {
        validate(password: password, confirmation: confirmation) == .all
    }
}

final class CloudBackupPasswordValidator {}

extension CloudBackupPasswordValidator: CloudBackupPasswordValidating {
    func validate(password: String?, confirmation: String?) -> CloudBackup.PasswordValidationResult {
        var result: CloudBackup.PasswordValidationResult = []

        guard let password, !password.isEmpty else {
            return []
        }

        if password.count >= CloudBackup.PasswordValidationResult.minLength {
            result = result.union([.minChars])
        }

        if password.rangeOfCharacter(from: .letters) != nil {
            result = result.union([.asciiChars])
        }

        if password.rangeOfCharacter(from: .decimalDigits) != nil {
            result = result.union([.digits])
        }

        if password == confirmation {
            result = result.union([.confirmMatchesPassword])
        }

        return result
    }
}
