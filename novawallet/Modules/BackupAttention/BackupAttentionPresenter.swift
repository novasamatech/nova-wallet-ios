import Foundation
import SoraFoundation

final class BackupAttentionPresenter {
    weak var view: BackupAttentionViewProtocol?
    let wireframe: BackupAttentionWireframeProtocol
    let interactor: BackupAttentionInteractorInputProtocol

    private var checkBoxViewModels: [CheckBoxIconDetailsView.Model] = []

    init(
        wireframe: BackupAttentionWireframeProtocol,
        interactor: BackupAttentionInteractorInputProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.localizationManager = localizationManager
    }
}

extension BackupAttentionPresenter: BackupAttentionPresenterProtocol {
    func setup() {
        let initialViewModel = makeInitialViewModel()
        checkBoxViewModels = initialViewModel.rows
        view?.didReceive(initialViewModel)
    }
}

private extension BackupAttentionPresenter {
    // swiftlint:disable function_body_length
    func makeInitialViewModel() -> BackupAttentionViewLayout.Model {
        let onCheckClosure: (UUID) -> Void = { [weak self] id in
            self?.changeCheckBoxState(for: id)
            self?.updateView()
        }

        return BackupAttentionViewLayout.Model(
            rows: [
                .init(
                    image: R.image.iconAttentionPassphrase(),
                    text: .attributed(
                        NSAttributedString.coloredItems(
                            [
                                R.string.localizable.backupAttentionPassphraseDescriptionHighlighted(
                                    preferredLanguages: selectedLocale.rLanguages
                                )
                            ],
                            formattingClosure: { items in
                                R.string.localizable.backupAttentionPassphraseDescription(
                                    items[0],
                                    preferredLanguages: selectedLocale.rLanguages
                                )
                            },
                            color: R.color.colorTextPrimary()!
                        )
                    ),
                    checked: false,
                    onCheck: onCheckClosure
                ),
                .init(
                    image: R.image.iconAttentionPassphraseWrite(),
                    text: .attributed(
                        NSAttributedString.coloredItems(
                            [
                                R.string.localizable.backupAttentionPassphraseWriteDescriptionHighlighted(
                                    preferredLanguages: selectedLocale.rLanguages
                                )
                            ],
                            formattingClosure: { items in
                                R.string.localizable.backupAttentionPassphraseWriteDescription(
                                    items[0],
                                    preferredLanguages: selectedLocale.rLanguages
                                )
                            },
                            color: R.color.colorTextPrimary()!
                        )
                    ),
                    checked: false,
                    onCheck: onCheckClosure
                ),
                .init(
                    image: R.image.iconAttentionPassphraseSupport(),
                    text: .attributed(
                        NSAttributedString.coloredItems(
                            [
                                R.string.localizable.backupAttentionPassphraseSupportDescriptionHighlighted(
                                    preferredLanguages: selectedLocale.rLanguages
                                )
                            ],
                            formattingClosure: { items in
                                R.string.localizable.backupAttentionPassphraseSupportDescription(
                                    items[0],
                                    preferredLanguages: selectedLocale.rLanguages
                                )
                            },
                            color: R.color.colorTextPrimary()!
                        )
                    ),
                    checked: false,
                    onCheck: onCheckClosure
                )
            ],
            button: .inactive(
                title: R.string.localizable.backupAttentionAggreeButtonTitle(
                    preferredLanguages: selectedLocale.rLanguages
                )
            )
        )
    }

    func updateView() {
        let newViewModel = makeViewModel()
        view?.didReceive(newViewModel)
    }

    func makeViewModel() -> BackupAttentionViewLayout.Model {
        let activeButtonTitle = R.string.localizable.commonContinue(
            preferredLanguages: selectedLocale.rLanguages
        )
        let inactiveButtonTitle = R.string.localizable.backupAttentionAggreeButtonTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        return BackupAttentionViewLayout.Model(
            rows: checkBoxViewModels,
            button: checkBoxViewModels
                .filter { $0.checked }
                .count == checkBoxViewModels.count
                ? .active(title: activeButtonTitle, action: continueTapped)
                : .inactive(title: inactiveButtonTitle)
        )
    }

    func changeCheckBoxState(for checkBoxId: UUID) {
        guard let index = checkBoxViewModels.firstIndex(where: { $0.id == checkBoxId }) else {
            return
        }
        let current = checkBoxViewModels[index]

        checkBoxViewModels[index] = CheckBoxIconDetailsView.Model(
            image: current.image,
            text: current.text,
            checked: !current.checked,
            onCheck: current.onCheck
        )
    }

    func continueTapped() {
        if interactor.checkIfMnemonicAvailable() {
            wireframe.showMnemonic(from: view)
        } else {
            wireframe.showExportSecrets(from: view)
        }
    }
}

// MARK: Localizable

extension BackupAttentionPresenter: Localizable {
    func applyLocalization() {
        updateView()
    }
}
