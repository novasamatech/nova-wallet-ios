import Foundation
import Foundation_iOS

final class SubtensorSubnetSelectPresenter {
    weak var view: SubtensorSubnetSelectViewProtocol?
    weak var delegate: SubtensorSubnetSelectDelegate?

    let wireframe: SubtensorSubnetSelectWireframeProtocol
    let interactor: SubnetSelectInteractorInputProtocol
    let viewModelFactory: SubtensorSubnetViewModelFactoryProtocol
    let earnSettings: SubtensorEarnSettingsProtocol

    private var entries: [SubtensorSubnetListItem]?
    private var entriesError: Error?
    private var weeklyPrices: [SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]?
    private var subnetLogos: SubtensorSubnetLogos?
    private var favourites: Set<SubtensorSubnetRef>
    private var query = ""
    let browseState: SubtensorSubnetBrowseState
    private var sort: SubtensorSubnetSort { browseState.sort }
    private var filters: SubtensorSubnetFilters { browseState.filters }
    private var pendingFilters: SubtensorSubnetFilters?
    private var list: SubtensorSubnetList?

    private weak var filtersView: SubtensorSubnetFiltersViewProtocol?
    private var requestedWeeklySubnets: Set<SubtensorSubnetRef> = []
    private var isWeeklyPending = false

    init(
        interactor: SubnetSelectInteractorInputProtocol,
        wireframe: SubtensorSubnetSelectWireframeProtocol,
        viewModelFactory: SubtensorSubnetViewModelFactoryProtocol,
        delegate: SubtensorSubnetSelectDelegate,
        earnSettings: SubtensorEarnSettingsProtocol,
        localizationManager: LocalizationManagerProtocol,
        browseState: SubtensorSubnetBrowseState = .init()
    ) {
        self.browseState = browseState
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.delegate = delegate
        self.earnSettings = earnSettings
        favourites = earnSettings.favouriteSubnets

        self.localizationManager = localizationManager
    }
}

private extension SubtensorSubnetSelectPresenter {
    func makeBuilder() -> SubtensorSubnetListBuilder? {
        guard let entries else {
            return nil
        }

        return SubtensorSubnetListBuilder(
            entries: entries,
            weekly: weeklyPrices,
            previousOrder: browseState.orderedRefs,
            favourites: favourites,
            locale: selectedLocale
        )
    }

    func provideList() {
        let builder = makeBuilder()
        list = builder?.build(query: query, sort: sort, filters: filters)
        if let builder { browseState.orderedRefs = builder.orderedRefs(sort: sort) }

        let state = SubtensorSubnetListState(
            list: list,
            sort: sort,
            filters: filters,
            subnetLogos: subnetLogos,
            stamp: entries.flatMap { SubtensorBackendStamp.aggregate($0.flatMap(\.subnet.stamps)) },
            entriesError: entriesError
        )

        view?.didReceive(list: viewModelFactory.createListViewModel(for: state, locale: selectedLocale))
    }

    func createFiltersViewModel(for draft: SubtensorSubnetFilters) -> SubtensorSubnetFiltersViewModel {
        let count = makeBuilder()?.build(query: query, sort: sort, filters: draft).count

        return viewModelFactory.createFiltersViewModel(
            filters: draft,
            count: count,
            locale: selectedLocale
        )
    }

    func provideFilters() {
        guard let pendingFilters, let filtersView else {
            return
        }

        filtersView.didReceive(viewModel: createFiltersViewModel(for: pendingFilters))
    }

    func requestWeeklyPricesIfNeeded() {
        guard let entries, !isWeeklyPending else {
            return
        }

        let subnets = entries.map(\.subnet.ref).filter { !requestedWeeklySubnets.contains($0) }

        guard !subnets.isEmpty else {
            return
        }

        requestedWeeklySubnets.formUnion(subnets)
        isWeeklyPending = true

        interactor.loadWeeklyPrices(for: subnets)
    }

    func applySort(_ newSort: SubtensorSubnetSort) {
        guard newSort.isAvailable else { return }
        browseState.sort = newSort

        provideList()
    }

    func findItem(for subnetRef: SubtensorSubnetRef) -> SubtensorSubnetListItem? {
        guard let list else {
            return nil
        }

        return (list.picks + list.others).first { $0.ref == subnetRef }
    }
}

extension SubtensorSubnetSelectPresenter: SubtensorSubnetSelectPresenterProtocol {
    func setup() {
        provideList()

        interactor.setup()
    }

    func becomeActive() {
        let storedFavourites = earnSettings.favouriteSubnets

        guard storedFavourites != favourites else {
            return
        }

        favourites = storedFavourites
        provideList()
    }

    func search(query: String) {
        self.query = query

        provideList()
    }

    func selectSubnet(_ subnetRef: SubtensorSubnetRef) {
        guard let delegate, let item = findItem(for: subnetRef) else {
            return
        }

        wireframe.showDetails(from: view, item: item, delegate: delegate)
    }

    func toggleFavorite(_ subnetRef: SubtensorSubnetRef) {
        favourites.formSymmetricDifference([subnetRef])
        earnSettings.favouriteSubnets = favourites
        provideList()
    }

    func selectRoot() {
        wireframe.complete(from: view, target: .root, validator: nil, delegate: delegate)
    }

    func showSort() {
        let viewModel = viewModelFactory.createSortSheetViewModel(selected: sort, locale: selectedLocale)

        wireframe.showSortSheet(from: view, viewModel: viewModel) { [weak self] index in
            let sorts = SubtensorSubnetSort.allCases

            guard sorts.indices.contains(index) else {
                return
            }

            self?.applySort(sorts[index])
        }
    }

    func showFilters() {
        pendingFilters = filters

        filtersView = wireframe.showFilters(
            from: view,
            viewModel: createFiltersViewModel(for: filters),
            onChange: { [weak self] draft in
                self?.draftFilters(draft)
            },
            onApply: { [weak self] draft in
                self?.applyFilters(draft)
            }
        )
    }

    func draftFilters(_ filters: SubtensorSubnetFilters) {
        pendingFilters = filters

        provideFilters()
    }

    func applyFilters(_ filters: SubtensorSubnetFilters) {
        browseState.filters = filters
        pendingFilters = nil

        provideList()
    }

    func retry() {
        entries = nil
        entriesError = nil
        provideList()

        interactor.refresh()
    }
}

extension SubtensorSubnetSelectPresenter: SubnetSelectInteractorOutputProtocol {
    func didReceive(entries: [SubtensorSubnetListItem]) {
        self.entries = entries
        entriesError = nil

        provideList()
        provideFilters()
        requestWeeklyPricesIfNeeded()
    }

    func didReceive(subnetLogos: SubtensorSubnetLogos?) {
        self.subnetLogos = subnetLogos

        provideList()
    }

    func didReceive(weeklyPrices: [SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]) {
        self.weeklyPrices = (self.weeklyPrices ?? [:]).merging(weeklyPrices) { _, new in new }
        isWeeklyPending = false

        provideList()
        requestWeeklyPricesIfNeeded()
    }

    func didReceiveError(_ error: Error) {
        entries = nil
        entriesError = error
        provideList()
    }
}

extension SubtensorSubnetSelectPresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else {
            return
        }

        provideList()
        provideFilters()
    }
}
