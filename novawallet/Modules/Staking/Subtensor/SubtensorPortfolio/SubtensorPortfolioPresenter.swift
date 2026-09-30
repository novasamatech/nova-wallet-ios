import Foundation
import Foundation_iOS

final class SubtensorPortfolioPresenter {
    weak var view: SubtensorPortfolioViewProtocol?

    let interactor: SubnetPortfolioInteractorInputProtocol
    let wireframe: SubtensorPortfolioWireframeProtocol
    let viewModelFactory: SubnetPortfolioViewModelFactoryProtocol
    let account: MetaChainAccountResponse
    let chainAsset: ChainAsset
    let localizationManager: LocalizationManagerProtocol

    private var state = SubtensorPortfolioState()
    private var weeklyChangesRequest: [SubtensorSubnetRef]?
    private var historiesRequest: HistoriesRequest?

    init(
        interactor: SubnetPortfolioInteractorInputProtocol,
        wireframe: SubtensorPortfolioWireframeProtocol,
        viewModelFactory: SubnetPortfolioViewModelFactoryProtocol,
        account: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.account = account
        self.chainAsset = chainAsset
        self.localizationManager = localizationManager
    }
}

private extension SubtensorPortfolioPresenter {
    struct HistoriesRequest: Equatable {
        let period: SubtensorPricePeriod
        let subnets: [SubtensorSubnetRef]
    }

    func provideViewModel() {
        let viewModel = viewModelFactory.createViewModel(for: state, locale: localizationManager.selectedLocale)
        view?.didReceive(viewModel: viewModel)
    }

    func requestPriceDataIfNeeded() {
        guard state.positions != nil, state.isCatalogueResolved else {
            return
        }

        let subnets = state.subnetRefs

        if weeklyChangesRequest != subnets {
            weeklyChangesRequest = subnets
            interactor.loadWeeklyChanges(for: subnets)
        }

        guard chainAsset.asset.priceId != nil else {
            return
        }

        let request = HistoriesRequest(period: state.period, subnets: subnets)

        guard historiesRequest != request else {
            return
        }

        historiesRequest = request
        state.histories = .loading
        interactor.loadHistories(for: request.period, subnets: request.subnets)
    }
}

extension SubtensorPortfolioPresenter: SubtensorPortfolioPresenterProtocol {
    func setup() {
        provideViewModel()
        interactor.setup()
    }

    func selectPeriod(at index: Int) {
        guard
            SubtensorPortfolioViewModelFactory.periods.indices.contains(index),
            SubtensorPortfolioViewModelFactory.periods[index] != state.period else {
            return
        }

        state.period = SubtensorPortfolioViewModelFactory.periods[index]
        state.histories = .loading
        requestPriceDataIfNeeded()
        provideViewModel()
    }

    func selectPosition(at index: Int) {
        let groups = state.groups

        guard groups.indices.contains(index) else {
            return
        }

        wireframe.showPosition(from: view, group: groups[index])
    }

    func addPosition() {
        switch SubtensorOperationGate.verdict(for: account.chainAccount.type) {
        case .allowed, .noSigning:
            wireframe.showAddPosition(from: view)
        case let .signerNotSupported(type):
            guard let view else { return }
            wireframe.presentSignerNotSupportedView(from: view, type: type) {}
        }
    }

    func retry() {
        interactor.refresh()
    }
}

extension SubtensorPortfolioPresenter: SubnetPortfolioInteractorOutputProtocol {
    func didReceive(state positions: Multistaking.SubtensorStakingState) {
        state.positions = positions
        requestPriceDataIfNeeded()
        provideViewModel()
    }

    func didReceive(catalogue: SubtensorSubnetCatalogue?) {
        state.isCatalogueResolved = true

        if let catalogue {
            state.catalogue = catalogue
        }

        requestPriceDataIfNeeded()
        provideViewModel()
    }

    func didReceive(subnetLogos: SubtensorSubnetLogos?) {
        state.subnetLogos = subnetLogos
        provideViewModel()
    }

    func didReceive(rootRate: Decimal?) {
        state.rootRate = rootRate
        provideViewModel()
    }

    func didReceive(price: PriceData?) {
        state.price = .loaded(price)
        provideViewModel()
    }

    func didReceive(histories: SubtensorPortfolioPriceHistories) {
        guard histories.period == state.period else {
            return
        }

        state.histories = .loaded(histories)
        provideViewModel()
    }

    func didFailHistories(for period: SubtensorPricePeriod) {
        guard period == state.period else {
            return
        }

        state.histories = .failed
        provideViewModel()
    }

    func didReceive(weeklyChanges: [SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]) {
        state.weeklyChanges = weeklyChanges
        provideViewModel()
    }

    func didReceiveSyncFailure(_ isFailed: Bool) {
        state.isSyncFailed = isFailed
        provideViewModel()
    }

    func didChangeCurrency() {
        state.price = .loading
        state.histories = .loading
        historiesRequest = nil
        requestPriceDataIfNeeded()
        provideViewModel()
    }

    func didReceiveAccountChange() {
        wireframe.close(from: view)
    }
}

extension SubtensorPortfolioPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            provideViewModel()
        }
    }
}
