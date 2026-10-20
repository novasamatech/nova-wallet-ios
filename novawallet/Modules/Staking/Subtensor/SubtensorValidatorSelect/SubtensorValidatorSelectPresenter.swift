import Foundation
import Foundation_iOS
import NovaAnalytics

final class SubtensorValidatorSelectPresenter {
    weak var view: SubtensorValidatorSelectViewProtocol?
    weak var delegate: SubtensorValidatorSelectDelegate?

    let target: SubtensorStakeTarget
    let interactor: SubtensorValidatorSelectInteractorInputProtocol
    let wireframe: SubtensorValidatorSelectWireframeProtocol
    let listFactory: SubtensorValidatorListFactory
    let abandonTracker: AnalyticsAbandonTracker
    let dataAnalytics = SubtensorDataAnalytics(screen: .validatorSelect)

    private var directory: SubtensorValidatorDirectory?
    private var directoryError: Error?
    private var yields: SubtensorAlphaYields?
    private var alphaPrice: Balance?
    private var recommendedHotkeys: Set<AccountId>?
    private var recommendedError: Error?
    private var verificationError: Error?
    private let filterSession: SubtensorValidatorFilterSession
    private var filters: SubtensorValidatorFilters
    private var query = ""
    private var selectedHotkey: AccountId?
    private var preselectedHotkey: AccountId?
    private let recommendedHotkey: AccountId?
    private var keptHotkeys: Set<AccountId> = []

    init(
        target: SubtensorStakeTarget,
        selectedHotkey: AccountId?,
        recommendedHotkey: AccountId?,
        interactor: SubtensorValidatorSelectInteractorInputProtocol,
        wireframe: SubtensorValidatorSelectWireframeProtocol,
        listFactory: SubtensorValidatorListFactory,
        delegate: SubtensorValidatorSelectDelegate,
        localizationManager: LocalizationManagerProtocol,
        filterSession: SubtensorValidatorFilterSession
    ) {
        self.target = target
        self.selectedHotkey = selectedHotkey
        preselectedHotkey = selectedHotkey
        self.recommendedHotkey = recommendedHotkey
        self.interactor = interactor
        self.wireframe = wireframe
        self.listFactory = listFactory
        self.delegate = delegate
        self.filterSession = filterSession
        filters = filterSession.applied(isRoot: target.isRoot)

        let analyticsTarget = target.analyticsTarget
        abandonTracker = AnalyticsAbandonTracker {
            AnalyticsEvent.subtensorStakingAbandoned(stage: .validatorSelect, target: analyticsTarget)
        }

        self.localizationManager = localizationManager
    }
}

private extension SubtensorValidatorSelectPresenter {
    func provideState() {
        let header = listFactory.createLoadingViewModel(yields: yields, sort: filters.sort, locale: selectedLocale)
        view?.didReceive(header: header, isFilterActive: filters.hidesUnusualApy)

        if let error = directoryError ?? verificationError ?? (filters.hidesUnusualApy ? recommendedError : nil) {
            let viewModel = listFactory.createErrorViewModel(for: error, locale: selectedLocale)
            view?.didReceive(state: .failed(viewModel))
            return
        }

        guard let directory, !filters.hidesUnusualApy || recommendedHotkeys != nil else {
            view?.didReceive(
                state: .loading(header)
            )
            return
        }

        let input = SubtensorValidatorListInput(
            directory: directory,
            yields: yields,
            alphaPrice: alphaPrice,
            isRoot: target.isRoot,
            sort: filters.sort,
            query: query,
            selectedHotkey: selectedHotkey,
            preselectedHotkey: preselectedHotkey,
            keptHotkeys: keptHotkeys,
            recommendedHotkeys: filters.hidesUnusualApy ? recommendedHotkeys : nil,
            showsUnreliableRates: !filters.hidesUnusualApy
        )

        view?.didReceive(state: .loaded(listFactory.createListViewModel(for: input, locale: selectedLocale)))
    }

    func selectableItem(for hotkey: AccountId?) -> SubtensorValidatorDirectoryItem? {
        directory?.items.first { $0.hotkey == hotkey }
    }

    func handedOut(_ item: SubtensorValidatorDirectoryItem) -> SubtensorValidatorDirectoryItem {
        var handedOut = item
        handedOut.reportedStake = directory?.listStamp?.freshness == .fresh ? item.reportedStake : nil
        return handedOut
    }

    func accepts(_ directory: SubtensorValidatorDirectory) -> Bool {
        directory.subnet.netuid == target.netuid &&
            (target.isRoot || directory.subnet.registeredAt == target.subnetInfo?.networkRegisteredAt)
    }

    func apply(directory: SubtensorValidatorDirectory) {
        guard accepts(directory) else { return }
        self.directory = directory
        directoryError = nil
        selectedHotkey = selectableItem(for: selectedHotkey)?.hotkey
        preselectedHotkey = selectableItem(for: preselectedHotkey)?.hotkey
    }

    func presentInactiveValidator() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        wireframe.present(
            message: strings.stakingSubtensorUiValidatorInactiveMessage(),
            title: strings.stakingSubtensorUiValidatorInactiveTitle(),
            closeAction: strings.commonClose(),
            from: view
        )
    }

    func seed(from snapshot: SubtensorValidatorSelectSnapshot) {
        if let directory = snapshot.directory.value, accepts(directory) {
            self.directory = directory
        }

        if let yields = snapshot.yields.value, yields.netuid == target.netuid {
            self.yields = yields
        }

        if let alphaPrice = snapshot.alphaPrice.value {
            self.alphaPrice = alphaPrice
        }
    }
}

extension SubtensorValidatorSelectPresenter: SubtensorValidatorSelectPresenterProtocol {
    func setup() {
        provideState()
        interactor.setup()
    }

    func retry() {
        let endpoint: BittensorDataEndpoint = if directoryError != nil {
            .validators
        } else if verificationError != nil {
            .chainRpc
        } else {
            .recommendations
        }

        dataAnalytics.trackRetry(endpoint)
        directory = nil
        directoryError = nil
        yields = nil
        recommendedHotkeys = nil
        recommendedError = nil
        verificationError = nil

        if !target.isRoot {
            alphaPrice = nil
        }

        provideState()
        interactor.retry()
    }

    func search(_ query: String) {
        self.query = query
        provideState()
    }

    func showSortOptions() {
        wireframe.showFilters(from: view, applied: filters, delegate: self)
    }

    func removeFilters() {
        filters.hidesUnusualApy = false
        provideState()
    }

    func select(hotkey: AccountId) {
        guard let item = selectableItem(for: hotkey) else {
            return
        }

        guard !item.isInactive else {
            presentInactiveValidator()
            return
        }

        if let selectedHotkey {
            keptHotkeys.insert(selectedHotkey)
        }

        selectedHotkey = hotkey
        provideState()
    }

    func showInfo(hotkey: AccountId) {
        wireframe.showValidatorInfo(
            from: view,
            target: target,
            hotkey: hotkey,
            detail: selectableItem(for: hotkey).map(handedOut),
            needsChainDetail: true
        )
    }

    func confirm() {
        guard let item = selectableItem(for: selectedHotkey), !item.isInactive else {
            return
        }

        let validator = handedOut(item)
        let target = target
        let delegate = delegate

        abandonTracker.markProceeded()

        if item.hotkey != preselectedHotkey, item.hotkey != recommendedHotkey {
            trackValidatorChanged(source: query.isEmpty ? .list : .search, unusualApyFilter: filters.hidesUnusualApy)
        }

        delegate?.didSelectValidator(validator, for: target)

        wireframe.complete(from: view) { [weak delegate] in
            delegate?.didCompleteValidatorSelection(validator, for: target)
        }
    }
}

extension SubtensorValidatorSelectPresenter: SubtensorValidatorSelectInteractorOutputProtocol {
    func didReceive(snapshot: SubtensorValidatorSelectSnapshot) {
        seed(from: snapshot)
        provideState()
    }

    func didReceive(directory: SubtensorValidatorDirectory) {
        apply(directory: directory)
        provideState()
    }

    func didFailDirectory(_ error: Error) {
        directory = nil
        directoryError = error
        provideState()

        dataAnalytics.trackFailure(error, endpoint: .validators)
    }

    func didReceive(yields: SubtensorAlphaYields?) {
        guard yields == nil || yields?.netuid == target.netuid else { return }
        self.yields = yields ?? self.yields
        provideState()
    }

    func didReceive(alphaPrice: Balance?) {
        self.alphaPrice = alphaPrice
        provideState()
    }

    func didReceive(verification: SubtensorValidatorListVerification) {
        directory = directory?.withVerification(verification)
        verificationError = nil

        if selectableItem(for: selectedHotkey)?.isInactive == true {
            selectedHotkey = nil
        }

        switch verification.recommended {
        case let .success(hotkeys):
            recommendedHotkeys = hotkeys
            recommendedError = nil
        case let .failure(error):
            recommendedHotkeys = nil
            recommendedError = error
        }

        provideState()

        if filters.hidesUnusualApy {
            dataAnalytics.trackFailure(recommendedError, endpoint: .recommendations)
        }
    }

    func didFailVerification(_ error: Error) {
        recommendedHotkeys = nil
        verificationError = error
        provideState()

        dataAnalytics.trackFailure(error, endpoint: .chainRpc)
    }
}

extension SubtensorValidatorSelectPresenter: SubtensorValidatorFiltersDelegate {
    func didReceiveValidator(filters newFilters: SubtensorValidatorFilters) {
        if newFilters.hidesUnusualApy != filters.hidesUnusualApy {
            keptHotkeys = []
        }

        filters = newFilters
        filterSession.apply(newFilters, isRoot: target.isRoot)
        provideState()
    }
}

extension SubtensorValidatorSelectPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            provideState()
        }
    }
}
