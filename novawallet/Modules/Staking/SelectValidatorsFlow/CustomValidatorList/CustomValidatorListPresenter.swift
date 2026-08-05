import Foundation
import Foundation_iOS

final class CustomValidatorListPresenter {
    weak var view: CustomValidatorListViewProtocol?

    let wireframe: CustomValidatorListWireframeProtocol
    let interactor: CustomValidatorListInteractorInputProtocol
    let viewModelFactory: CustomValidatorListViewModelFactory
    let selectedValidatorList: SharedList<SelectedValidatorInfo>
    let validatorsSelectionParams: ValidatorsSelectionParams
    let logger: LoggerProtocol?

    private let recommendedValidatorList: [SelectedValidatorInfo]
    private let fullValidatorList: CustomValidatorsFullList
    private let lockedAddresses: Set<AccountAddress>
    private let selectionCounter: ValidatorSelectionCounter

    private var filteredValidatorList: [SelectedValidatorInfo] = []
    private var viewModel: CustomValidatorListViewModel?
    private var filter: CustomValidatorListFilter
    private var priceData: PriceData?

    init(
        interactor: CustomValidatorListInteractorInputProtocol,
        wireframe: CustomValidatorListWireframeProtocol,
        viewModelFactory: CustomValidatorListViewModelFactory,
        localizationManager: LocalizationManagerProtocol,
        fullValidatorList: CustomValidatorsFullList,
        recommendedValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        validatorsSelectionParams: ValidatorsSelectionParams,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.fullValidatorList = fullValidatorList
        self.recommendedValidatorList = recommendedValidatorList
        self.selectedValidatorList = selectedValidatorList
        self.validatorsSelectionParams = validatorsSelectionParams
        self.logger = logger
        lockedAddresses = fullValidatorList.lockedAddresses
        selectionCounter = ValidatorSelectionCounter(
            lockedAddresses: fullValidatorList.lockedAddresses,
            maxNominations: validatorsSelectionParams.maxNominations
        )
        filter = CustomValidatorListFilter.recommendedFilter(
            havingIdentity: validatorsSelectionParams.hasIdentity
        )
        self.localizationManager = localizationManager
    }

    // MARK: - Private functions

    private func composeFilteredValidatorList() -> [SelectedValidatorInfo] {
        let composer = CustomValidatorListComposer(filter: filter)
        return composer.compose(
            from: fullValidatorList.allValidators,
            preferrences: fullValidatorList.preferredValidators
        )
    }

    private func updateFilteredValidatorsList() {
        filteredValidatorList = composeFilteredValidatorList()
    }

    private func provideValidatorListViewModel() {
        let viewModel = viewModelFactory.createViewModel(
            from: filteredValidatorList,
            selectedValidatorList: selectedValidatorList.items,
            totalValidatorsCount: fullValidatorList.distinctCount(),
            filter: filter,
            priceData: priceData,
            locale: selectedLocale
        )

        self.viewModel = viewModel
        view?.reload(viewModel)
    }

    private func provideFilterButtonViewModel() {
        let emptyFilter = CustomValidatorListFilter.defaultFilter()
        let appliedState = filter != emptyFilter

        view?.setFilterAppliedState(to: appliedState)
    }

    private func provideViewModels() {
        updateFilteredValidatorsList()

        provideValidatorListViewModel()
        provideFilterButtonViewModel()
    }

    private func performDeselect() {
        guard var viewModel = viewModel else { return }

        let changedModels: [CustomValidatorCellViewModel] = viewModel.cellViewModels.map {
            var newItem = $0
            newItem.isSelected = newItem.isLocked && newItem.isSelected
            return newItem
        }

        let indices = viewModel.cellViewModels
            .enumerated()
            .filter { $1.isSelected && !$1.isLocked }
            .map { index, _ in index }

        let keptValidators = selectedValidatorList.items.filter {
            lockedAddresses.contains($0.address)
        }

        selectedValidatorList.set(keptValidators)

        viewModel.cellViewModels = changedModels
        viewModel.selection = selectionCounter.state(for: selectedValidatorList.items)
        self.viewModel = viewModel

        view?.reload(viewModel, at: indices)
    }
}

// MARK: - CustomValidatorListPresenterProtocol

extension CustomValidatorListPresenter: CustomValidatorListPresenterProtocol {
    func setup() {
        provideViewModels()
        interactor.setup()
    }

    // MARK: - Header actions

    func fillWithRecommended() {
        let selection = selectionCounter.state(for: selectedValidatorList.items)
        let freeSlots = max(selection.communityLimit - selection.communitySelected, 0)

        let recommendedToFill = recommendedValidatorList
            .filter { !selectedValidatorList.contains($0) }
            .prefix(freeSlots)

        guard !recommendedToFill.isEmpty else { return }

        selectedValidatorList.append(contentsOf: recommendedToFill)
        provideViewModels()
    }

    func clearFilter() {
        filter = CustomValidatorListFilter.defaultFilter()
        provideViewModels()
    }

    func deselectAll() {
        guard let view = view else { return }

        wireframe.presentDeselectValidatorsWarning(
            from: view,
            action: performDeselect,
            locale: selectedLocale
        )
    }

    // MARK: - Cell actions

    func changeValidatorSelection(at index: Int) {
        guard var viewModel = viewModel else { return }

        let changedValidator = filteredValidatorList[index]

        guard !lockedAddresses.contains(changedValidator.address) else {
            wireframe.present(
                message: R.string(
                    preferredLanguages: selectedLocale.rLanguages
                ).localizable.stakingCustomLockedValidatorMessage(),
                title: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonWarning(),
                closeAction: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonClose(),
                from: view
            )
            return
        }

        guard !changedValidator.blocked else {
            wireframe.present(
                message: R.string(
                    preferredLanguages: selectedLocale.rLanguages
                ).localizable.stakingCustomBlockedWarning(),
                title: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonWarning(),
                closeAction: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonClose(),
                from: view
            )
            return
        }

        if let selectedIndex = selectedValidatorList.firstIndex(of: changedValidator) {
            selectedValidatorList.remove(at: selectedIndex)
        } else {
            selectedValidatorList.append(changedValidator)
        }

        viewModel.cellViewModels[index].isSelected = !viewModel.cellViewModels[index].isSelected
        viewModel.selection = selectionCounter.state(for: selectedValidatorList.items)
        self.viewModel = viewModel

        view?.reload(viewModel, at: [index])
    }

    // MARK: - Presenting actions

    func didSelectValidator(at index: Int) {
        let selectedValidator = filteredValidatorList[index]
        wireframe.present(selectedValidator, from: view)
    }

    func presentFilter() {
        wireframe.presentFilters(
            from: view,
            filter: filter,
            hasIdentity: validatorsSelectionParams.hasIdentity,
            delegate: self
        )
    }

    func presentSearch() {
        wireframe.presentSearch(
            from: view,
            fullValidatorList: fullValidatorList.distinctAll(),
            selectedValidatorList: selectedValidatorList.items,
            delegate: self
        )
    }

    func proceed() {
        wireframe.proceed(
            from: view,
            validatorList: selectedValidatorList.items,
            maxTargets: validatorsSelectionParams.maxNominations,
            delegate: self
        )
    }
}

// MARK: - CustomValidatorListInteractorOutputProtocol

extension CustomValidatorListPresenter: CustomValidatorListInteractorOutputProtocol {
    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData
            provideValidatorListViewModel()

        case let .failure(error):
            logger?.error("Price data subscription error: \(error)")
        }
    }
}

// MARK: - SelectedValidatorListDelegate

extension CustomValidatorListPresenter: SelectedValidatorListDelegate {
    func didRemove(_ validator: SelectedValidatorInfo) {
        guard !lockedAddresses.contains(validator.address) else {
            return
        }

        if let displayedIndex = filteredValidatorList.firstIndex(of: validator) {
            changeValidatorSelection(at: displayedIndex)
        } else if let selectedIndex = selectedValidatorList.firstIndex(of: validator) {
            selectedValidatorList.remove(at: selectedIndex)
            provideViewModels()
        }
    }
}

// MARK: - ValidatorListFilterDelegate

extension CustomValidatorListPresenter: ValidatorListFilterDelegate {
    func didUpdate(_ filter: CustomValidatorListFilter) {
        self.filter = filter
        provideViewModels()
    }
}

// MARK: - ValidatorSearchDelegate

extension CustomValidatorListPresenter: ValidatorSearchDelegate {
    func validatorSearchDidUpdate(selectedValidatorList: [SelectedValidatorInfo]) {
        self.selectedValidatorList.set(selectedValidatorList)

        provideViewModels()
    }
}

// MARK: - Localizable

extension CustomValidatorListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModels()
        }
    }
}
