import Foundation
import Foundation_iOS
import BigInt

final class SubtensorSubnetSelectPresenter {
    weak var view: SubtensorSubnetSelectViewProtocol?
    let wireframe: SubtensorSubnetSelectWireframeProtocol
    let interactor: SubnetSelectInteractorInputProtocol
    let viewModelFactory: SubtensorSubnetViewModelFactoryProtocol
    let logger: LoggerProtocol
    let earnSettings: SubtensorEarnSettingsProtocol

    weak var delegate: SubtensorSubnetSelectDelegate?

    /// the take of the hotkey the flow will actually stake with; the chain-wide
    /// default is only a fallback until it is known
    let preferredTake: UInt16?

    private(set) var subnetsInfo: SubtensorSubnetsInfo?
    private(set) var defaultTake: UInt16?
    private(set) var query: String = ""
    private(set) var sort: SubtensorSubnetSort = .favorites
    private(set) var filters = SubtensorSubnetFilters()
    private var weeklyChanges: [SubtensorSubnetRef: Decimal] = [:]
    private var monthlyMetrics: [SubtensorSubnetRef: SubtensorMonthlyPriceMetrics] = [:]
    private var monthlyRequested = false
    private var monthlyLoaded = false

    init(
        interactor: SubnetSelectInteractorInputProtocol,
        wireframe: SubtensorSubnetSelectWireframeProtocol,
        viewModelFactory: SubtensorSubnetViewModelFactoryProtocol,
        delegate: SubtensorSubnetSelectDelegate,
        preferredTake: UInt16?,
        earnSettings: SubtensorEarnSettingsProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.delegate = delegate
        self.preferredTake = preferredTake
        self.earnSettings = earnSettings
        self.logger = logger

        self.localizationManager = localizationManager
    }
}

private extension SubtensorSubnetSelectPresenter {
    func requestMonthlyMetricsIfNeeded() {
        guard !monthlyRequested,
              let subnetsInfo,
              sort == .thirtyDayChange || filters.onlyAboveThirtyDayAverage else { return }
        monthlyRequested = true
        interactor.loadMonthlyMetrics(for: subnetsInfo)
    }

    func provideViewModels() {
        guard let subnetsInfo else {
            view?.didReceive(viewModels: [])
            return
        }

        let viewModels = viewModelFactory.createViewModels(
            from: subnetsInfo,
            context: SubtensorSubnetViewModelContext(
                defaultTake: preferredTake ?? defaultTake,
                query: query,
                weeklyChanges: weeklyChanges,
                favorites: Set(earnSettings.favouriteSubnets),
                locale: selectedLocale
            )
        )

        let root = viewModels.filter { $0.target.isRoot }
        let sorted = viewModels.filter(matchesFilters).sorted(by: isOrderedBefore)

        view?.didReceive(viewModels: root + sorted)
    }

    func matchesFilters(_ model: SubtensorSubnetSelectViewModel) -> Bool {
        guard let info = model.target.subnetInfo else { return false }
        if filters.hideThinPools,
           info.taoIn < BigUInt(20000) * SubtensorStakingPallet.alphaPriceScale {
            return false
        }
        if filters.onlyAboveThirtyDayAverage, monthlyLoaded {
            guard let subnetRef = model.subnetRef,
                  let mean = monthlyMetrics[subnetRef]?.meanTaoPerAlpha,
                  let currentPrice = model.target.listedPrice,
                  let price = Decimal(string: String(currentPrice)),
                  let scale = Decimal(string: String(SubtensorStakingPallet.alphaPriceScale)) else { return false }
            return price / scale > mean
        }
        return true
    }

    func isOrderedBefore(_ lhs: SubtensorSubnetSelectViewModel, _ rhs: SubtensorSubnetSelectViewModel) -> Bool {
        switch sort {
        case .favorites:
            if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
            return isWeeklyBefore(lhs, rhs)
        case .sevenDayChange:
            return isWeeklyBefore(lhs, rhs)
        case .thirtyDayChange:
            return isMonthlyBefore(lhs, rhs)
        case .poolDepth:
            let left = lhs.target.subnetInfo?.taoIn ?? 0
            let right = rhs.target.subnetInfo?.taoIn ?? 0
            return left == right ? lhs.target.netuid < rhs.target.netuid : left > right
        case .volume:
            let left = lhs.target.subnetInfo?.subnetVolume ?? 0
            let right = rhs.target.subnetInfo?.subnetVolume ?? 0
            return left == right ? lhs.target.netuid < rhs.target.netuid : left > right
        case .age:
            let left = lhs.target.subnetInfo?.networkRegisteredAt ?? 0
            let right = rhs.target.subnetInfo?.networkRegisteredAt ?? 0
            return left == right ? lhs.target.netuid < rhs.target.netuid : left < right
        case .name:
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        case .subnetNumber:
            return lhs.target.netuid < rhs.target.netuid
        }
    }

    func isWeeklyBefore(_ lhs: SubtensorSubnetSelectViewModel, _ rhs: SubtensorSubnetSelectViewModel) -> Bool {
        if let left = lhs.weeklyChange, let right = rhs.weeklyChange, left != right {
            return left > right
        }
        if (lhs.weeklyChange == nil) != (rhs.weeklyChange == nil) {
            return lhs.weeklyChange != nil
        }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    func isMonthlyBefore(_ lhs: SubtensorSubnetSelectViewModel, _ rhs: SubtensorSubnetSelectViewModel) -> Bool {
        let left = lhs.subnetRef.flatMap { monthlyMetrics[$0]?.changeInTao }
        let right = rhs.subnetRef.flatMap { monthlyMetrics[$0]?.changeInTao }
        if let left, let right, left != right { return left > right }
        if (left == nil) != (right == nil) { return left != nil }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }
}

extension SubtensorSubnetSelectPresenter: SubtensorSubnetSelectPresenterProtocol {
    func setup() {
        view?.didReceiveLoading(true)
        interactor.setup()
    }

    func search(query: String) {
        self.query = query

        provideViewModels()
    }

    func select(viewModel: SubtensorSubnetSelectViewModel) {
        guard let delegate else { return }
        if viewModel.target.isRoot {
            delegate.didSelectStakeTarget(.root)
            wireframe.complete(from: view)
            return
        }
        wireframe.showDetails(from: view, model: viewModel, delegate: delegate)
    }

    func toggleFavorite(viewModel: SubtensorSubnetSelectViewModel) {
        guard let subnetRef = viewModel.subnetRef else { return }

        var favorites = Set(earnSettings.favouriteSubnets)
        if favorites.contains(subnetRef) {
            favorites.remove(subnetRef)
        } else {
            favorites.insert(subnetRef)
        }

        earnSettings.favouriteSubnets = favorites.sorted { $0.netuid < $1.netuid }
        provideViewModels()
    }

    func selectSort(_ sort: SubtensorSubnetSort) {
        self.sort = sort
        requestMonthlyMetricsIfNeeded()
        provideViewModels()
    }

    func selectFilters(_ filters: SubtensorSubnetFilters) {
        self.filters = filters
        requestMonthlyMetricsIfNeeded()
        provideViewModels()
    }
}

extension SubtensorSubnetSelectPresenter: SubnetSelectInteractorOutputProtocol {
    func didReceiveSubnetsInfo(_ info: SubtensorSubnetsInfo) {
        subnetsInfo = info
        monthlyMetrics = [:]
        monthlyRequested = false
        monthlyLoaded = false

        provideViewModels()
        view?.didReceiveLoading(false)
        requestMonthlyMetricsIfNeeded()
    }

    func didReceiveWeeklyChanges(_ changes: [SubtensorSubnetRef: Decimal]) {
        weeklyChanges = changes
        provideViewModels()
    }

    func didReceiveMonthlyMetrics(_ metrics: [SubtensorSubnetRef: SubtensorMonthlyPriceMetrics]) {
        monthlyMetrics = metrics
        monthlyLoaded = true
        provideViewModels()
    }

    func didFailMonthlyMetrics() {
        monthlyRequested = false
        monthlyLoaded = false
        provideViewModels()
    }

    func didReceiveDefaultTake(_ take: UInt16) {
        defaultTake = take

        provideViewModels()
    }

    func didReceiveError(_ error: Error) {
        logger.error("Subnets fetch failed: \(error)")
        view?.didReceiveLoading(false)

        wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
            self?.interactor.refresh()
        }
    }
}

extension SubtensorSubnetSelectPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideViewModels()
        }
    }
}
