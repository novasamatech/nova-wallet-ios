import Foundation
import Foundation_iOS

final class SubtensorPositionPresenter {
    weak var view: SubtensorPositionViewProtocol?

    let interactor: SubtensorPositionInteractorInputProtocol
    let wireframe: SubtensorPositionWireframeProtocol
    let viewModelFactory: SubtensorPositionViewModelFactoryProtocol
    let wallet: MetaAccountModel?
    let account: MetaChainAccountResponse?
    let chainAsset: ChainAsset

    var state: SubtensorPositionState
    var target: SubtensorStakeTarget?
    var validatorRequest: ValidatorRequest?
    private var historyRequest: HistoryRequest?
    var isSubnetsRefreshForced = false
    var isSubnetsInfoUnavailable = false
    var isClosed = false
    var isOpenedTracked = false
    var isHoldsResolved = false
    let dataAnalytics = SubtensorDataAnalytics(screen: .position)

    init(
        group: SubtensorPortfolioGroup,
        wallet: MetaAccountModel?,
        account: MetaChainAccountResponse?,
        chainAsset: ChainAsset,
        interactor: SubtensorPositionInteractorInputProtocol,
        wireframe: SubtensorPositionWireframeProtocol,
        viewModelFactory: SubtensorPositionViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        state = SubtensorPositionState(netuid: group.netuid, group: group)
        self.wallet = wallet
        self.account = account
        self.chainAsset = chainAsset
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory

        if state.isRoot {
            target = .root
        }

        self.localizationManager = localizationManager
    }
}

extension SubtensorPositionPresenter {
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
        trackOpenedIfReady()
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
            state.history = state.catalogue == nil ? .failed : .notListed
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

    func perform(_ action: SubtensorPositionAction, account: MetaChainAccountResponse) {
        switch action {
        case .claim:
            if let model = state.claimRewardsModel(for: account, chainFormat: chainAsset.chain.chainFormat) {
                wireframe.showClaimRewards(from: view, model: model)
            }
        case .addStake:
            if let primary = state.primaryPosition {
                wireframe.showAddStake(from: view, position: primary)
            }
        case .buy:
            if let primary = state.primaryPosition {
                wireframe.showBuyMore(from: view, position: primary)
            }
        case .unstake, .sell:
            wireframe.showUnstake(from: view, netuid: state.netuid)
        }
    }

    func resolveCatalogue() {
        state.isCatalogueResolved = true
        loadValidatorIfNeeded()
        requestHistoryIfNeeded()
        provideViewModel()
    }

    func retrySubnetsInfoIfUnavailable() {
        guard isSubnetsInfoUnavailable else {
            return
        }

        isSubnetsInfoUnavailable = false
        interactor.loadSubnetsInfo()
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
        let periods = SubtensorPricePeriod.subnetSelectable

        guard periods.indices.contains(index), periods[index] != state.period else {
            return
        }

        state.period = periods[index]
        requestHistoryIfNeeded()
        provideViewModel()
    }

    func selectAction(_ action: SubtensorPositionAction) {
        if action == .claim {
            interactor.refreshPendingClaims()
        }

        guard let wallet, let account, action == .claim || state.primaryPosition != nil, state.isEnabled(action) else {
            return
        }

        wireframe.checkingSupport(
            of: .subtensorStaking(chain: chainAsset.chain),
            for: wallet,
            sheetPresentingView: view,
            onRefusal: { [weak self] result in
                guard let reason = result.subtensorBlockedReason else {
                    return
                }

                self?.trackActionRefusal(action, reason: reason, wallet: wallet)
            },
            successClosure: { [weak self] in
                self?.perform(action, account: account)
            }
        )
    }

    func selectValidator() {
        guard let hotkey = state.group?.primaryHotkey else {
            return
        }

        guard let target else {
            retrySubnetsInfoIfUnavailable()
            return
        }

        let detail = state.isValidatorResolved ? state.validator : nil
        let needsChainDetail = detail?.isChainDetailUnavailable == true

        wireframe.showValidatorInfo(
            from: view, target: target, hotkey: hotkey, detail: detail, needsChainDetail: needsChainDetail
        )
    }

    func retrySync() {
        dataAnalytics.trackRetry(.chainRpc)
        interactor.refreshPositions()
        loadValidatorIfNeeded()
    }

    func retryHistory() {
        dataAnalytics.trackRetry(state.catalogue == nil ? .subnets : .coingecko)
        historyRequest = nil

        if state.catalogue == nil {
            state.history = .loading
            interactor.loadPrices()
        } else {
            requestHistoryIfNeeded()
        }

        provideViewModel()
    }

    func refresh() {
        validatorRequest = nil
        interactor.refreshAll()

        if let group = state.group {
            apply(group: group)
        }

        if state.history == .failed {
            historyRequest = nil
            state.history = .loading
            provideViewModel()
        } else if let historyRequest {
            interactor.loadHistory(for: historyRequest.subnet, period: historyRequest.period)
        }
    }

    func selectChart(_ selection: SubtensorPriceChartSelection?) {
        state.chartSelection = selection

        if let header = viewModelFactory.createPriceHeader(for: state, locale: selectedLocale) {
            view?.didReceive(priceHeader: header)
        }
    }
}

extension SubtensorPositionPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            provideViewModel()
        }
    }
}
