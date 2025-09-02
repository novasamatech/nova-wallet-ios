import Foundation
import Foundation_iOS

protocol CheckboxListViewProtocol: AnyObject {
    func update(using checkboxListViewModel: BackupAttentionViewLayout.Model)
}

protocol CheckboxListPresenterTrait: AnyObject {
    var checkboxView: CheckboxListViewProtocol? { get }
    var localizationManager: LocalizationManagerProtocol { get }
    var checkboxViewModels: [CheckBoxIconDetailsView.Model] { get set }

    func continueTapped()
}

extension CheckboxListPresenterTrait {
    func checkBoxTapped(_ id: UUID) {
        changeCheckBoxState(for: id)
        updateCheckBoxListView()
    }

    func updateCheckBoxListView() {
        let newViewModel = makeViewModel()
        checkboxView?.update(using: newViewModel)
    }

    func changeCheckBoxState(for checkBoxId: UUID) {
        guard let index = checkboxViewModels.firstIndex(where: { $0.id == checkBoxId }) else {
            return
        }
        let current = checkboxViewModels[index]

        checkboxViewModels[index] = CheckBoxIconDetailsView.Model(
            image: current.image,
            text: current.text,
            checked: !current.checked,
            onCheck: current.onCheck
        )
    }

    private func makeViewModel() -> BackupAttentionViewLayout.Model {
        let activeButtonTitle = R.string.localizable.commonContinue(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )
        let inactiveButtonTitle = R.string.localizable.backupAttentionAggreeButtonTitle(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )

        return BackupAttentionViewLayout.Model(
            rows: checkboxViewModels,
            button: checkboxViewModels
                .filter { $0.checked }
                .count == checkboxViewModels.count
                ? .active(title: activeButtonTitle, action: continueTapped)
                : .inactive(title: inactiveButtonTitle)
        )
    }
}
