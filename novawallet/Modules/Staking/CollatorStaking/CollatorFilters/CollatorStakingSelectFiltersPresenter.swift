import Foundation
import Foundation_iOS

final class CollatorStakingSelectFiltersPresenter {
    weak var view: CollatorStakingSelectFiltersViewProtocol?
    weak var delegate: CollatorStakingSelectFiltersDelegate?
    let wireframe: CollatorStakingSelectFiltersWireframeProtocol

    private var currentSorting: CollatorsSortType
    private var initialSorting: CollatorsSortType

    private let sortingTypes: [CollatorsSortType]

    init(
        wireframe: CollatorStakingSelectFiltersWireframeProtocol,
        sorting: CollatorsSortType,
        sortingTypes: [CollatorsSortType],
        delegate: CollatorStakingSelectFiltersDelegate,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        initialSorting = sorting
        currentSorting = sorting
        self.sortingTypes = sortingTypes
        self.delegate = delegate
        self.localizationManager = localizationManager
    }

    private func createTitle(for sorting: CollatorsSortType) -> String {
        switch sorting {
        case .rewards:
            return R.string(preferredLanguages: selectedLocale.rLanguages
            ).localizable.parastkCollatorsFilterRewards()
        case .minStake:
            return R.string(preferredLanguages: selectedLocale.rLanguages
            ).localizable.stakingMainMinimumStakeTitle()
        case .totalStake:
            return R.string(preferredLanguages: selectedLocale.rLanguages
            ).localizable.stakingValidatorTotalStake()
        case .ownStake:
            return R.string(preferredLanguages: selectedLocale.rLanguages
            ).localizable.parastkCollatorsFilterOwnStake()
        }
    }

    private func provideViewModel() {
        let sortingViewModels: [SelectableViewModel<String>] = sortingTypes.map { sortingType in
            let title = createTitle(for: sortingType)
            let isSelected = sortingType == currentSorting

            return SelectableViewModel(underlyingViewModel: title, selectable: isSelected)
        }

        let canApply = currentSorting != initialSorting
        let canReset = currentSorting != CollatorsSortType.defaultType

        let viewModel = CollatorStakingSelectFiltersViewModel(
            sorting: sortingViewModels,
            canApply: canApply,
            canReset: canReset
        )

        view?.didReceive(viewModel: viewModel)
    }
}

extension CollatorStakingSelectFiltersPresenter: CollatorStakingSelectFiltersPresenterProtocol {
    func setup() {
        provideViewModel()
    }

    func applyFilter() {
        delegate?.didReceiveCollator(sorting: currentSorting)

        wireframe.close(view: view)
    }

    func resetFilter() {
        currentSorting = CollatorsSortType.defaultType

        provideViewModel()
    }

    func selectSorting(at index: Int) {
        currentSorting = sortingTypes[index]

        provideViewModel()
    }
}

extension CollatorStakingSelectFiltersPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModel()
        }
    }
}
