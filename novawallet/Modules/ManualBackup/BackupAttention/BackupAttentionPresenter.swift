import Foundation
import Foundation_iOS

final class BackupAttentionPresenter: CheckboxListPresenterTrait {
    weak var view: BackupAttentionViewProtocol?

    var checkboxView: CheckboxListViewProtocol? { view }

    let wireframe: BackupAttentionWireframeProtocol
    let interactor: BackupAttentionInteractorInputProtocol
    let checkboxListViewModelFactory: CheckboxListViewModelFactory
    let localizationManager: LocalizationManagerProtocol

    var checkboxViewModels: [CheckBoxIconDetailsView.Model] = []

    init(
        wireframe: BackupAttentionWireframeProtocol,
        interactor: BackupAttentionInteractorInputProtocol,
        checkboxListViewModelFactory: CheckboxListViewModelFactory,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.checkboxListViewModelFactory = checkboxListViewModelFactory
        self.localizationManager = localizationManager
    }

    func continueTapped() {
        if interactor.checkIfMnemonicAvailable() {
            wireframe.showMnemonic(from: view)
        } else {
            wireframe.showExportSecrets(from: view)
        }
    }
}

// MARK: BackupAttentionPresenterProtocol

extension BackupAttentionPresenter: BackupAttentionPresenterProtocol {
    func setup() {
        checkboxViewModels = checkboxListViewModelFactory.makeWarningsInitialViewModel(
            showingIcons: true,
            checkBoxTapped
        )

        updateCheckBoxListView()
    }
}

// MARK: Localizable

extension BackupAttentionPresenter: Localizable {
    func applyLocalization() {
        updateCheckBoxListView()
    }
}
