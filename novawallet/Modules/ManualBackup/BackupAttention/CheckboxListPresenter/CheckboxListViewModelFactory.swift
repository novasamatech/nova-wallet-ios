import UIKit
import Foundation_iOS

class CheckboxListViewModelFactory {
    let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    func makeWarningsInitialViewModel(
        showingIcons: Bool,
        _ onCheckClosure: @escaping (UUID) -> Void
    ) -> [CheckBoxIconDetailsView.Model] {
        [
            createDoNotShareIt(showingIcon: showingIcons, onCheckClosure),
            createFundsMayBeLost(showingIcon: showingIcons, onCheckClosure),
            createBewareOfImpersonators(showingIcon: showingIcons, onCheckClosure)
        ]
    }

    private func createDoNotShareIt(
        showingIcon: Bool,
        _ onCheckClosure: @escaping (UUID) -> Void
    ) -> CheckBoxIconDetailsView.Model {
        .init(
            image: showingIcon ? R.image.iconAttentionPassphrase() : nil,
            text: .attributed(
                NSAttributedString.coloredItems(
                    [
                        R.string.localizable.backupAttentionPassphraseDescriptionHighlighted(
                            preferredLanguages: localizationManager.selectedLocale.rLanguages
                        )
                    ],
                    formattingClosure: { items in
                        R.string.localizable.backupAttentionPassphraseDescription(
                            items[0],
                            preferredLanguages: localizationManager.selectedLocale.rLanguages
                        )
                    },
                    color: R.color.colorTextPrimary()!
                )
            ),
            checked: false,
            onCheck: onCheckClosure
        )
    }

    private func createFundsMayBeLost(
        showingIcon: Bool,
        _ onCheckClosure: @escaping (UUID) -> Void
    ) -> CheckBoxIconDetailsView.Model {
        .init(
            image: showingIcon ? R.image.iconAttentionPassphraseWrite() : nil,
            text: .attributed(
                NSAttributedString.coloredItems(
                    [
                        R.string.localizable.backupAttentionPassphraseWriteDescriptionHighlighted(
                            preferredLanguages: localizationManager.selectedLocale.rLanguages
                        )
                    ],
                    formattingClosure: { items in
                        R.string.localizable.backupAttentionPassphraseWriteDescription(
                            items[0],
                            preferredLanguages: localizationManager.selectedLocale.rLanguages
                        )
                    },
                    color: R.color.colorTextPrimary()!
                )
            ),
            checked: false,
            onCheck: onCheckClosure
        )
    }

    private func createBewareOfImpersonators(
        showingIcon: Bool,
        _ onCheckClosure: @escaping (UUID) -> Void
    ) -> CheckBoxIconDetailsView.Model {
        .init(
            image: showingIcon ? R.image.iconAttentionPassphraseSupport() : nil,
            text: .attributed(
                NSAttributedString.coloredItems(
                    [
                        R.string.localizable.backupAttentionPassphraseSupportDescriptionHighlighted(
                            preferredLanguages: localizationManager.selectedLocale.rLanguages
                        )
                    ],
                    formattingClosure: { items in
                        R.string.localizable.backupAttentionPassphraseSupportDescription(
                            items[0],
                            preferredLanguages: localizationManager.selectedLocale.rLanguages
                        )
                    },
                    color: R.color.colorTextPrimary()!
                )
            ),
            checked: false,
            onCheck: onCheckClosure
        )
    }
}
