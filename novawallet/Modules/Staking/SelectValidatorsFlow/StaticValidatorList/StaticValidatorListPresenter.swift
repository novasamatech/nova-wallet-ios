import Foundation
import Foundation_iOS

final class StaticValidatorListPresenter {
    weak var view: StaticValidatorListViewProtocol?

    let wireframe: StaticValidatorListWireframeProtocol
    let viewModelFactory: SelectedValidatorListViewModelFactory
    let maxTargets: Int

    private var selectedValidatorList: [SelectedValidatorInfo]

    init(
        wireframe: StaticValidatorListWireframeProtocol,
        viewModelFactory: SelectedValidatorListViewModelFactory,
        selectedValidatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.selectedValidatorList = selectedValidatorList
        self.maxTargets = maxTargets
        self.localizationManager = localizationManager
    }

    // MARK: - Private functions

    private func provideViewModel() {
        let viewModel = viewModelFactory.createViewModel(
            from: selectedValidatorList,
            totalValidatorsCount: maxTargets,
            locale: selectedLocale
        )

        view?.didReload(viewModel)
    }
}

// MARK: - SelectedValidatorListPresenterProtocol

extension StaticValidatorListPresenter: StaticValidatorListPresenterProtocol {
    func setup() {
        provideViewModel()
    }

    func didSelectValidator(at index: Int) {
        let validatorInfo = selectedValidatorList[index]
        wireframe.present(validatorInfo, from: view)
    }
}

// MARK: - Localizable

extension StaticValidatorListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModel()
        }
    }
}
