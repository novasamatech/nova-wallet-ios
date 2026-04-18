import Foundation_iOS

final class SelectedValidatorListPresenter {
    weak var view: SelectedValidatorListViewProtocol?
    weak var delegate: SelectedValidatorListDelegate?

    let wireframe: SelectedValidatorListWireframeProtocol
    let viewModelFactory: SelectedValidatorListViewModelFactory
    let maxTargets: Int
    let preferredAddresses: Set<AccountAddress>

    private var selectedValidatorList: [SelectedValidatorInfo]

    init(
        wireframe: SelectedValidatorListWireframeProtocol,
        viewModelFactory: SelectedValidatorListViewModelFactory,
        localizationManager: LocalizationManagerProtocol,
        selectedValidatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        preferredAddresses: Set<AccountAddress> = []
    ) {
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.selectedValidatorList = selectedValidatorList
        self.maxTargets = maxTargets
        self.preferredAddresses = preferredAddresses
        self.localizationManager = localizationManager
    }

    // MARK: - Private functions

    private func createViewModel() -> SelectedValidatorListViewModel {
        viewModelFactory.createViewModel(
            from: selectedValidatorList,
            totalValidatorsCount: maxTargets,
            preferredAddresses: preferredAddresses,
            locale: selectedLocale
        )
    }

    private func provideViewModel() {
        let viewModel = createViewModel()
        view?.didReload(viewModel)
    }
}

// MARK: - SelectedValidatorListPresenterProtocol

extension SelectedValidatorListPresenter: SelectedValidatorListPresenterProtocol {
    func setup() {
        provideViewModel()
    }

    func didSelectValidator(at index: Int) {
        let validatorInfo = selectedValidatorList[index]
        wireframe.present(validatorInfo, from: view)
    }

    func removeItem(at index: Int) {
        let validator = selectedValidatorList[index]

        guard !preferredAddresses.contains(validator.address) else {
            return
        }

        selectedValidatorList.remove(at: index)

        let viewModel = createViewModel()
        view?.didChangeViewModel(viewModel, byRemovingItemAt: index)

        delegate?.didRemove(validator)
    }

    func proceed() {
        wireframe.proceed(
            from: view,
            targets: selectedValidatorList,
            maxTargets: maxTargets
        )
    }

    func dismiss() {
        wireframe.dismiss(view)
    }
}

// MARK: - Localizable

extension SelectedValidatorListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModel()
        }
    }
}
