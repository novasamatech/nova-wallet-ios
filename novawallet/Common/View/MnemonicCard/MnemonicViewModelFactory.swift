import Foundation
import Foundation_iOS

struct MnemonicViewModelFactory {
    let localizationManager: LocalizationManagerProtocol

    func createCardTitle() -> NSAttributedString {
        NSAttributedString.coloredItems(
            [
                R.string.localizable.mnemonicCardRevealedHeaderMessageHighlighted(
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                )
            ],
            formattingClosure: { items in
                R.string.localizable.mnemonicCardRevealedHeaderMessage(
                    items[0],
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                )
            },
            color: R.color.colorTextPrimary()!
        )
    }

    func createMnemonicCardViewModel(for words: [String]) -> MnemonicCardView.Model {
        .init(
            units: words.map { .wordView(text: $0) },
            title: createCardTitle()
        )
    }

    func createEmptyMnemonicCardViewModel(for words: [String]) -> MnemonicCardView.Model {
        .init(
            units: words.map { _ in .viewHolder },
            title: createCardTitle()
        )
    }

    func createMnemonicGridViewModel(for words: [String]) -> [MnemonicGridView.UnitType] {
        words.map { .wordView(text: $0) }
    }

    func createMnemonicCardHiddenModel() -> HiddenMnemonicCardView.CoverModel {
        .init(
            title: R.string.localizable.mnemonicCardCoverMessageTitle(
                preferredLanguages: localizationManager.selectedLocale.rLanguages
            ),
            message: R.string.localizable.mnemonicCardCoverMessageMessage(
                preferredLanguages: localizationManager.selectedLocale.rLanguages
            )
        )
    }
}
