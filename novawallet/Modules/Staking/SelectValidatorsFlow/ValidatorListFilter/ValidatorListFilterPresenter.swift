import Foundation_iOS

final class ValidatorListFilterPresenter {
    weak var view: ValidatorListFilterViewProtocol?
    weak var delegate: ValidatorListFilterDelegate?

    let wireframe: ValidatorListFilterWireframeProtocol
    let viewModelFactory: ValidatorListFilterViewModelFactoryProtocol

    let assetInfo: AssetBalanceDisplayInfo
    let initialFilter: CustomValidatorListFilter
    let hasIdentity: Bool
    private(set) var currentFilter: CustomValidatorListFilter

    init(
        wireframe: ValidatorListFilterWireframeProtocol,
        viewModelFactory: ValidatorListFilterViewModelFactoryProtocol,
        assetInfo: AssetBalanceDisplayInfo,
        filter: CustomValidatorListFilter,
        hasIdentity: Bool,
        localizationManager: LocalizationManager
    ) {
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.assetInfo = assetInfo
        initialFilter = filter
        currentFilter = filter
        self.hasIdentity = hasIdentity
        self.localizationManager = localizationManager
    }

    private func provideViewModels() {
        let viewModel = viewModelFactory.createViewModel(
            from: currentFilter,
            initialFilter: initialFilter,
            hasIdentity: hasIdentity,
            token: assetInfo.symbol,
            locale: selectedLocale
        )
        view?.didUpdateViewModel(viewModel)
    }
}

extension ValidatorListFilterPresenter: ValidatorListFilterPresenterProtocol {
    func setup() {
        provideViewModels()
    }

    func toggleFilter(for viewModel: ValidatorListFilterCellViewModel<ValidatorListFilterRow>) {
        switch viewModel.type {
        case .withoutIdentity:
            currentFilter.allowsNoIdentity = !currentFilter.allowsNoIdentity
        case .slashed:
            currentFilter.allowsSlashed = !currentFilter.allowsSlashed
        case .oversubscribed:
            currentFilter.allowsOversubscribed = !currentFilter.allowsOversubscribed
        case .clusterLimit:
            let allowsUnlimitedClusters = currentFilter.allowsClusters == .unlimited
            currentFilter.allowsClusters = allowsUnlimitedClusters ?
                .limited(amount: StakingConstants.targetsClusterLimit) :
                .unlimited
        }

        provideViewModels()
    }

    func selectSorting(for viewModel: ValidatorListFilterCellViewModel<ValidatorListSortRow>) {
        currentFilter.sortedBy = viewModel.type.sortCriterion
        provideViewModels()
    }

    func applyFilter() {
        delegate?.didUpdate(currentFilter)
        wireframe.close(view)
    }

    func resetFilter() {
        currentFilter = CustomValidatorListFilter.recommendedFilter(havingIdentity: hasIdentity)
        provideViewModels()
    }
}

extension ValidatorListFilterPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModels()
        }
    }
}
