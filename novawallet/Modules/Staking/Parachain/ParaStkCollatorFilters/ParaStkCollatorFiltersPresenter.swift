import Foundation
import SoraFoundation

final class ParaStkCollatorFiltersPresenter {
    weak var view: ParaStkCollatorFiltersViewProtocol?
    weak var delegate: ParaStkCollatorFiltersDelegate?
    let wireframe: ParaStkCollatorFiltersWireframeProtocol

    private var currentSorting: CollatorsSortType
    private var initialSorting: CollatorsSortType

    private let sortingTypes: [CollatorsSortType] = [.rewards, .minStake, .totalStake, .ownStake]

    init(
        wireframe: ParaStkCollatorFiltersWireframeProtocol,
        sorting: CollatorsSortType,
        delegate: ParaStkCollatorFiltersDelegate,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        initialSorting = sorting
        currentSorting = sorting
        self.delegate = delegate
        self.localizationManager = localizationManager
    }

    private func createTitle(for sorting: CollatorsSortType) -> String {
        switch sorting {
        case .rewards:
            return R.string.localizable.parastkCollatorsFilterRewards(
                preferredLanguages: selectedLocale.rLanguages
            )
        case .minStake:
            return R.string.localizable.parastkCollatorsFilterMinStake(
                preferredLanguages: selectedLocale.rLanguages
            )
        case .totalStake:
            return R.string.localizable.parastkCollatorsFilterTotalStake(
                preferredLanguages: selectedLocale.rLanguages
            )
        case .ownStake:
            return R.string.localizable.parastkCollatorsFilterOwnStake(
                preferredLanguages: selectedLocale.rLanguages
            )
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

        let viewModel = ParaStkCollatorFiltersViewModel(
            sorting: sortingViewModels,
            canApply: canApply,
            canReset: canReset
        )

        view?.didReceive(viewModel: viewModel)
    }
}

extension ParaStkCollatorFiltersPresenter: ParaStkCollatorFiltersPresenterProtocol {
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

extension ParaStkCollatorFiltersPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModel()
        }
    }
}
