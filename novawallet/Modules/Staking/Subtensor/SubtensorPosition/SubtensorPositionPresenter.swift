import Foundation
import Foundation_iOS

final class SubtensorPositionPresenter {
    weak var view: SubtensorPositionViewProtocol?

    let interactor: SubtensorPositionInteractorInputProtocol
    let wireframe: SubtensorPositionWireframeProtocol
    let viewModelFactory: SubnetPositionViewModelFactoryProtocol
    let account: MetaChainAccountResponse?

    private var state: SubtensorPositionState
    private var target: SubtensorStakeTarget?
    private var validatorRequest: ValidatorRequest?
    private var historyRequest: HistoryRequest?
    private var isCatalogueRefreshForced = false
    private var isSubnetsRefreshForced = false
    private var isSubnetsInfoUnavailable = false
    private var isClosed = false

    init(
        group: SubtensorPortfolioGroup,
        account: MetaChainAccountResponse?,
        interactor: SubtensorPositionInteractorInputProtocol,
        wireframe: SubtensorPositionWireframeProtocol,
        viewModelFactory: SubnetPositionViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        state = SubtensorPositionState(netuid: group.netuid, group: group)
        self.account = account
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory

        if state.isRoot {
            target = .root
        }

        self.localizationManager = localizationManager
    }
}

private extension SubtensorPositionPresenter {
    struct HistoryRequest: Equatable {
        let subnet: SubtensorSubnetRef
        let period: SubtensorPricePeriod
    }

    struct ValidatorRequest: Equatable {
        let hotkey: AccountId
        let subnet: SubtensorSubnetRef
    }

    var subnetRef: SubtensorSubnetRef {
        state.catalogue?.subnet(for: state.netuid)?.ref ??
            SubtensorSubnetRef(netuid: state.netuid, registeredAt: 0)
    }

    func provideViewModel() {
        view?.didReceive(viewModel: viewModelFactory.createViewModel(for: state, locale: selectedLocale))
    }

    func loadValidatorIfNeeded() {
        guard let hotkey = state.group?.primaryHotkey else {
            return
        }

        let request = ValidatorRequest(hotkey: hotkey, subnet: subnetRef)

        guard request != validatorRequest else {
            return
        }

        validatorRequest = request
        interactor.loadValidator(hotkey, on: request.subnet)
    }

    func apply(group: SubtensorPortfolioGroup) {
        state.group = group

        loadValidatorIfNeeded()

        if state.isRoot {
            interactor.loadRootHolds(for: group.positions.map(\.hotkey))
        }
    }

    func requestHistoryIfNeeded() {
        guard !state.isRoot, state.isCatalogueResolved else {
            return
        }

        guard let subnet = state.catalogue?.subnet(for: state.netuid)?.ref else {
            state.history = .notListed
            state.hasResolvedHistory = true
            return
        }

        let request = HistoryRequest(subnet: subnet, period: state.period)

        guard request != historyRequest else {
            return
        }

        historyRequest = request
        state.history = .loading
        interactor.loadHistory(for: subnet, period: request.period)
    }

    func perform(_ action: SubtensorPositionAction, primary: SubtensorStakingPosition) {
        switch action {
        case .addStake:
            wireframe.showAddStake(from: view, position: primary)
        case .buy:
            wireframe.showBuyMore(from: view, position: primary)
        case .unstake, .sell:
            wireframe.showUnstake(from: view, netuid: state.netuid)
        }
    }

    func retrySubnetsInfoIfUnavailable() {
        guard isSubnetsInfoUnavailable else {
            return
        }

        isSubnetsInfoUnavailable = false
        interactor.loadSubnetsInfo(forcingRefresh: true)
    }
}

extension SubtensorPositionPresenter: SubtensorPositionPresenterProtocol {
    func setup() {
        provideViewModel()
        interactor.setup()

        if let group = state.group {
            apply(group: group)
        }
    }

    func selectPeriod(at index: Int) {
        let periods = SubtensorPositionViewModelFactory.periods

        guard periods.indices.contains(index), periods[index] != state.period else {
            return
        }

        state.period = periods[index]
        requestHistoryIfNeeded()
        provideViewModel()
    }

    func selectAction(_ action: SubtensorPositionAction) {
        guard let account, let primary = state.primaryPosition, state.isEnabled(action) else {
            return
        }

        switch SubtensorOperationGate.verdict(for: account.chainAccount.type) {
        case .allowed, .noSigning:
            perform(action, primary: primary)
        case let .signerNotSupported(type):
            guard let view else {
                return
            }

            wireframe.presentSignerNotSupportedView(from: view, type: type) {}
        }
    }

    func selectValidator() {
        guard let hotkey = state.group?.primaryHotkey else {
            return
        }

        guard let target else {
            retrySubnetsInfoIfUnavailable()
            return
        }

        let detail = state.isValidatorResolved
            ? state.validator.map { SubtensorValidatorDetail(item: $0, identity: nil) }
            : nil

        wireframe.showValidatorInfo(from: view, target: target, hotkey: hotkey, detail: detail)
    }

    func retrySync() {
        interactor.refreshPositions()
    }

    func retryHistory() {
        historyRequest = nil
        requestHistoryIfNeeded()
        provideViewModel()
    }
}

extension SubtensorPositionPresenter: SubnetPositionInteractorOutputProtocol {
    func didReceive(group: SubtensorPortfolioGroup?) {
        guard let group else {
            guard !isClosed else {
                return
            }

            isClosed = true
            wireframe.popToPortfolio(from: view)
            return
        }

        apply(group: group)
        provideViewModel()
    }

    func didReceiveSyncFailure(_ isFailed: Bool) {
        state.isSyncFailed = isFailed
        provideViewModel()
    }

    func didReceive(price: PriceData?) {
        state.price = .loaded(price)
        provideViewModel()
    }

    func didChangeCurrency() {
        state.price = .loading
        provideViewModel()
    }

    func didReceive(catalogue: SubtensorSubnetCatalogue?) {
        if let catalogue {
            state.catalogue = catalogue
        }

        if catalogue != nil, state.catalogue?.subnet(for: state.netuid) == nil, !isCatalogueRefreshForced {
            isCatalogueRefreshForced = true
            interactor.loadCatalogue(forcingRefresh: true)
            return
        }

        state.isCatalogueResolved = true
        loadValidatorIfNeeded()
        requestHistoryIfNeeded()
        provideViewModel()
    }

    func didReceive(subnetsInfo: SubtensorSubnetsInfo?) {
        guard
            let subnet = subnetsInfo?.subnets.first(where: { $0.netuid == state.netuid }),
            let price = subnetsInfo?.prices[state.netuid] else {
            if isSubnetsRefreshForced {
                isSubnetsInfoUnavailable = true
            } else {
                isSubnetsRefreshForced = true
                interactor.loadSubnetsInfo(forcingRefresh: true)
            }

            return
        }

        target = .subnet(info: subnet, price: price)
    }

    func didReceive(earnConfig: SubtensorEarnConfig?) {
        state.earnConfig = earnConfig
        provideViewModel()
    }

    func didReceive(validator: SubtensorValidatorDirectoryItem?, for hotkey: AccountId) {
        guard hotkey == state.group?.primaryHotkey else {
            return
        }

        state.validatorHotkey = hotkey
        state.validator = validator
        provideViewModel()
    }

    func didReceive(rootRate: Decimal?) {
        state.isRateResolved = true
        state.rootRate = rootRate
        provideViewModel()
    }

    func didReceive(yields: SubtensorAlphaYields?) {
        state.isRateResolved = true
        state.yields = yields
        provideViewModel()
    }

    func didReceive(claimable: SubtensorRootClaimable?) {
        state.claimable = claimable
        provideViewModel()
    }

    func didReceiveClaimableFailure(_ isFailed: Bool) {
        state.isClaimableFailed = isFailed
        provideViewModel()
    }

    func didReceive(holds: [AccountId: SubtensorRootHold]) {
        state.holds = holds
        provideViewModel()
    }

    func didReceive(blockNumber: BlockNumber) {
        state.blockNumber = blockNumber
        provideViewModel()
    }

    func didReceive(history: SubtensorPriceHistoryResult, for period: SubtensorPricePeriod) {
        guard period == state.period else {
            return
        }

        switch history {
        case let .available(priceHistory):
            state.history = .available(priceHistory)
        case .notListed:
            state.history = .notListed
        }

        state.hasResolvedHistory = true
        provideViewModel()
    }

    func didFailHistory(for period: SubtensorPricePeriod) {
        guard period == state.period else {
            return
        }

        state.history = .failed
        state.hasResolvedHistory = true
        provideViewModel()
    }
}

extension SubtensorPositionPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            provideViewModel()
        }
    }
}
