import Foundation

protocol CloudBackupPasswordValidating {
    func validate(with type: CloudBackup.PasswordValidationType) -> CloudBackup.PasswordValidationResult
}

extension CloudBackupPasswordValidating {
    func isValid(with validationType: CloudBackup.PasswordValidationType) -> Bool {
        validate(with: validationType) == .all(for: validationType)
    }
}

final class CloudBackupPasswordValidator {}

extension CloudBackupPasswordValidator: CloudBackupPasswordValidating {
    func validate(with type: CloudBackup.PasswordValidationType) -> CloudBackup.PasswordValidationResult {
        switch type {
        case let .newPassword(password):
            return validatePassword(password)
        case let .confirmation(password, confirmation):
            var partialResult = validatePassword(confirmation)

            if password == confirmation {
                partialResult = partialResult.union([.confirmMatchesPassword])
            }

            return partialResult
        }
    }

    private func validatePassword(_ password: String?) -> CloudBackup.PasswordValidationResult {
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

        return result
    }
}
