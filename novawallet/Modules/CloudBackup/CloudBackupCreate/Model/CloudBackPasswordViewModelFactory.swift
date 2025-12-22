import Foundation

protocol CloudBackPasswordViewModelFactoryProtocol {
    func createHints(
        from result: CloudBackup.PasswordValidationResult,
        locale: Locale
    ) -> [HintListView.ViewModel]
}

final class CloudBackPasswordViewModelFactory {
    private let flow: CloudBackupSetupPasswordFlow

    init(flow: CloudBackupSetupPasswordFlow) {
        self.flow = flow
    }

    func createViewModel(for text: String, isMatches: Bool) -> HintListView.ViewModel {
        let color = isMatches ? R.color.colorTextPositive()! : R.color.colorTextSecondary()!

        let icon = R.image.iconCheckmark()?.withRenderingMode(.alwaysTemplate).tinted(with: color)

        let attributedString = NSAttributedString(
            string: text,
            attributes: [.foregroundColor: color]
        )

        return .init(icon: icon, attributedText: attributedString)
    }
}

extension CloudBackPasswordViewModelFactory: CloudBackPasswordViewModelFactoryProtocol {
    func createHints(
        from result: CloudBackup.PasswordValidationResult,
        locale: Locale
    ) -> [HintListView.ViewModel] {
        var hints = [
            createViewModel(
                for: R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupCreateHintMinChar(
                    "\(CloudBackup.PasswordValidationResult.minLength)"
                ),
                isMatches: result.contains(.minChars)
            ),
            createViewModel(
                for: R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupCreateHintNumbers(),
                isMatches: result.contains(.digits)
            ),
            createViewModel(
                for: R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupCreateHintLetters(),
                isMatches: result.contains(.asciiChars)
            )
        ]

        if flow == .confirmPassword {
            hints.append(
                createViewModel(
                    for: R.string(
                        preferredLanguages: locale.rLanguages
                    ).localizable.cloudBackupCreateHintPasswordMatch(),
                    isMatches: result.contains(.confirmMatchesPassword)
                )
            )
        }

        return hints
    }
}
