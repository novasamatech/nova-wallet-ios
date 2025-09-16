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
                        R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages
                        ).localizable.backupAttentionPassphraseDescriptionHighlighted()
                    ],
                    formattingClosure: { items in
                        R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages
                        ).localizable.backupAttentionPassphraseDescription(items[0])
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
                        R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages
                        ).localizable.backupAttentionPassphraseWriteDescriptionHighlighted()
                    ],
                    formattingClosure: { items in
                        R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages
                        ).localizable.backupAttentionPassphraseWriteDescription(items[0])
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
                        R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages
                        ).localizable.backupAttentionPassphraseSupportDescriptionHighlighted()
                    ],
                    formattingClosure: { items in
                        R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages
                        ).localizable.backupAttentionPassphraseSupportDescription(items[0])
                    },
                    color: R.color.colorTextPrimary()!
                )
            ),
            checked: false,
            onCheck: onCheckClosure
        )
    }
}
