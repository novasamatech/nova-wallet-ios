import Foundation
import Foundation_iOS

final class SubtensorSubnetSelectPresenter {
    weak var view: SubtensorSubnetSelectViewProtocol?
    weak var delegate: SubtensorSubnetSelectDelegate?

    let wireframe: SubtensorSubnetSelectWireframeProtocol
    let interactor: SubnetSelectInteractorInputProtocol
    let viewModelFactory: SubtensorSubnetViewModelFactoryProtocol
    let earnSettings: SubtensorEarnSettingsProtocol

    private var entries: [SubtensorSubnetListEntry]?
    private var weeklyPrices: [SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]?
    private var ageBlocks: [UInt16: UInt64] = [:]
    private var subnetLogos: SubtensorSubnetLogos?
    private var rootRate: Decimal?
    private var favourites: Set<SubtensorSubnetRef>
    private var query = ""
    private var sort: SubtensorSubnetSort = .sevenDayChange
    private var filters = SubtensorSubnetFilters()
    private var pendingFilters: SubtensorSubnetFilters?
    private var list: SubtensorSubnetList?

    private weak var filtersView: SubtensorSubnetFiltersViewProtocol?
    private var requestedWeeklySubnets: Set<SubtensorSubnetRef> = []
    private var isWeeklyPending = false
    private var hasExpiredAgesSeed = false

    init(
        interactor: SubnetSelectInteractorInputProtocol,
        wireframe: SubtensorSubnetSelectWireframeProtocol,
        viewModelFactory: SubtensorSubnetViewModelFactoryProtocol,
        delegate: SubtensorSubnetSelectDelegate,
        earnSettings: SubtensorEarnSettingsProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.delegate = delegate
        self.earnSettings = earnSettings
        favourites = Set(earnSettings.favouriteSubnets)

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
            ageBlocks: ageBlocks,
            favourites: favourites,
            locale: selectedLocale
        )
    }

    func provideList() {
        list = makeBuilder()?.build(query: query, sort: sort, filters: filters)

        let state = SubtensorSubnetListState(
            list: list,
            sort: sort,
            filters: filters,
            subnetLogos: subnetLogos
        )

        view?.didReceive(list: viewModelFactory.createListViewModel(for: state, locale: selectedLocale))
    }

    func provideRootBar() {
        view?.didReceive(rootBar: viewModelFactory.createRootBarViewModel(annualRate: rootRate, locale: selectedLocale))
    }

    func makeAgeBlocks(from rankedSubnets: SubtensorRankedSubnets?) -> [UInt16: UInt64] {
        Dictionary(
            (rankedSubnets?.items ?? []).compactMap { item in item.ageBlocks.map { (item.netuid, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func seed(from snapshot: SubtensorSubnetSelectSnapshot) {
        if let entries = snapshot.entries.value {
            self.entries = entries
        }

        if let rootRate = snapshot.rootRate.value {
            self.rootRate = rootRate
        }

        if let rankedSubnets = snapshot.rankedSubnets.value {
            ageBlocks = makeAgeBlocks(from: rankedSubnets)
            hasExpiredAgesSeed = !snapshot.rankedSubnets.isFresh
        }
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

    func retryEntries() {
        entries = nil
        provideList()

        interactor.refresh()
    }

    func applySort(_ newSort: SubtensorSubnetSort) {
        sort = newSort

        provideList()
    }

    func findItem(for subnetRef: SubtensorSubnetRef) -> SubtensorSubnetListItem? {
        guard let list else {
            return nil
        }

        return (list.picks + list.others).first { $0.ref == subnetRef }
    }

    func storeFavourites() {
        earnSettings.favouriteSubnets = favourites.sorted { lhs, rhs in
            lhs.netuid != rhs.netuid ? lhs.netuid < rhs.netuid : lhs.registeredAt < rhs.registeredAt
        }
    }
}

extension SubtensorSubnetSelectPresenter: SubtensorSubnetSelectPresenterProtocol {
    func setup() {
        seed(from: interactor.cachedSnapshot())

        provideList()
        provideRootBar()

        interactor.setup()

        requestWeeklyPricesIfNeeded()
    }

    func becomeActive() {
        let storedFavourites = Set(earnSettings.favouriteSubnets)

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
        if favourites.contains(subnetRef) {
            favourites.remove(subnetRef)
        } else {
            favourites.insert(subnetRef)
        }

        storeFavourites()
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
        self.filters = filters
        pendingFilters = nil

        provideList()
    }
}

extension SubtensorSubnetSelectPresenter: SubnetSelectInteractorOutputProtocol {
    func didReceive(entries: [SubtensorSubnetListEntry]) {
        self.entries = entries

        provideList()
        provideFilters()
        requestWeeklyPricesIfNeeded()
    }

    func didReceive(subnetLogos: SubtensorSubnetLogos?) {
        self.subnetLogos = subnetLogos

        provideList()
    }

    func didReceive(rootRate: Decimal?) {
        self.rootRate = rootRate

        provideRootBar()
    }

    func didReceive(rankedSubnets: SubtensorRankedSubnets?) {
        guard rankedSubnets != nil || !hasExpiredAgesSeed else {
            return
        }

        ageBlocks = makeAgeBlocks(from: rankedSubnets)

        provideList()
    }

    func didReceive(weeklyPrices: [SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]) {
        self.weeklyPrices = (self.weeklyPrices ?? [:]).merging(weeklyPrices) { _, new in new }
        isWeeklyPending = false

        provideList()
        requestWeeklyPricesIfNeeded()
    }

    func didReceiveError(_ error: Error) {
        entries = []
        provideList()

        if let apiError = error as? BittensorApiError, apiError.isDeviceBound {
            return
        }

        wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
            self?.retryEntries()
        }
    }
}

extension SubtensorSubnetSelectPresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else {
            return
        }

        provideList()
        provideRootBar()
        provideFilters()
    }
}
