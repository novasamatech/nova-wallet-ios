import UIKit
import SoraFoundation

class CheckboxListViewModelFactory {
    let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    // swiftlint:disable function_body_length
    func makeWarningsInitialViewModel(
        showingIcons: Bool,
        _ onCheckClosure: @escaping (UUID) -> Void
    ) -> [CheckBoxIconDetailsView.Model] {
        [
            .init(
                image: showingIcons ? R.image.iconAttentionPassphrase() : nil,
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
            ),
            .init(
                image: showingIcons ? R.image.iconAttentionPassphraseWrite() : nil,
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
            ),
            .init(
                image: showingIcons ? R.image.iconAttentionPassphraseSupport() : nil,
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
        ]
    }
}
