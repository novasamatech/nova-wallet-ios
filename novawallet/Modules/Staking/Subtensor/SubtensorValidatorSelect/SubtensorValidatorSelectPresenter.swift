import Foundation
import Foundation_iOS

final class SubtensorValidatorSelectPresenter {
    weak var view: SubtensorValidatorSelectViewProtocol?
    weak var delegate: SubtensorValidatorSelectDelegate?

    let target: SubtensorStakeTarget
    let interactor: ValidatorSelectInteractorInputProtocol
    let wireframe: ValidatorSelectWireframeProtocol
    let listFactory: SubtensorValidatorListFactory

    private var directory: SubtensorValidatorDirectory?
    private var directoryError: Error?
    private var yields: SubtensorAlphaYields?
    private var alphaPrice: Balance?
    private var recommendedHotkeys: Set<AccountId>?
    private var recommendedError: Error?
    private var verificationError: Error?
    private let filterSession: SubtensorValidatorFilterSession
    private var query = ""
    private var selectedHotkey: AccountId?
    private var preselectedHotkey: AccountId?
    private var keptHotkeys: Set<AccountId> = []

    init(
        target: SubtensorStakeTarget,
        selectedHotkey: AccountId?,
        interactor: ValidatorSelectInteractorInputProtocol,
        wireframe: ValidatorSelectWireframeProtocol,
        listFactory: SubtensorValidatorListFactory,
        delegate: SubtensorValidatorSelectDelegate,
        localizationManager: LocalizationManagerProtocol,
        filterSession: SubtensorValidatorFilterSession
    ) {
        self.target = target
        self.selectedHotkey = selectedHotkey
        preselectedHotkey = selectedHotkey
        self.interactor = interactor
        self.wireframe = wireframe
        self.listFactory = listFactory
        self.delegate = delegate
        self.filterSession = filterSession
        self.localizationManager = localizationManager
    }
}

private extension SubtensorValidatorSelectPresenter {
    var filters: SubtensorValidatorFilters { filterSession.applied(isRoot: target.isRoot) }

    func provideState() {
        let filters = filters
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
            recommendedHotkeys: filters.hidesUnusualApy ? recommendedHotkeys : nil
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

extension SubtensorValidatorSelectPresenter: ValidatorSelectPresenterProtocol {
    func setup() {
        seed(from: interactor.cachedSnapshot())
        provideState()
        interactor.setup()
    }

    func retry() {
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
        wireframe
            .showFilters(from: view, applied: filters) { [weak self] filters in
                guard let self else { return }
                if filters.hidesUnusualApy != self.filters.hidesUnusualApy { keptHotkeys = [] }
                filterSession.apply(filters, isRoot: target.isRoot)
                provideState()
            }
    }

    func select(hotkey: AccountId) {
        guard selectableItem(for: hotkey) != nil else {
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
        guard let item = selectableItem(for: selectedHotkey) else {
            return
        }

        delegate?.didSelectValidator(handedOut(item), for: target)
        wireframe.complete(from: view)
    }
}

extension SubtensorValidatorSelectPresenter: ValidatorSelectInteractorOutputProtocol {
    func didReceive(directory: SubtensorValidatorDirectory) {
        apply(directory: directory)
        provideState()
    }

    func didFailDirectory(_ error: Error) {
        directory = nil
        directoryError = error
        provideState()
    }

    func didReceive(yields: SubtensorAlphaYields?) {
        guard yields == nil || yields?.netuid == target.netuid else { return }
        self.yields = yields
        provideState()
    }

    func didReceive(alphaPrice: Balance?) {
        self.alphaPrice = alphaPrice
        provideState()
    }

    func didReceive(verification: SubtensorValidatorListVerification) {
        directory = directory?.withTakes(verification.takes)
        verificationError = nil

        switch verification.recommended {
        case let .success(hotkeys):
            recommendedHotkeys = hotkeys
            recommendedError = nil
        case let .failure(error):
            recommendedHotkeys = nil
            recommendedError = error
        }

        provideState()
    }

    func didFailVerification(_ error: Error) {
        recommendedHotkeys = nil
        verificationError = error
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
