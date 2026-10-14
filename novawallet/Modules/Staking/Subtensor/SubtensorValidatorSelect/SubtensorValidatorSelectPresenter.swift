import Foundation
import Foundation_iOS

final class SubtensorValidatorSelectPresenter {
    weak var view: SubtensorValidatorSelectViewProtocol?
    weak var delegate: SubtensorValidatorSelectDelegate?

    let target: SubtensorStakeTarget
    let interactor: ValidatorSelectInteractorInputProtocol
    let wireframe: ValidatorSelectWireframeProtocol
    let listFactory: SubtensorValidatorListFactory
    let logger: LoggerProtocol

    private var directory: SubtensorValidatorDirectory?
    private var directoryError: Error?
    private var clientGates: SubtensorClientGates?
    private var clientGatesError: Error?
    private var yields: SubtensorAlphaYields?
    private var alphaPrice: Balance?
    private let filterSession: SubtensorValidatorFilterSession
    private var sort: SubtensorValidatorSort
    private var query = ""
    private var selectedHotkey: AccountId?
    private var preselectedHotkey: AccountId?

    init(
        target: SubtensorStakeTarget,
        selectedHotkey: AccountId?,
        interactor: ValidatorSelectInteractorInputProtocol,
        wireframe: ValidatorSelectWireframeProtocol,
        listFactory: SubtensorValidatorListFactory,
        delegate: SubtensorValidatorSelectDelegate,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol,
        filterSession: SubtensorValidatorFilterSession = SubtensorValidatorFilterSession()
    ) {
        self.target = target
        self.selectedHotkey = selectedHotkey
        self.interactor = interactor
        self.wireframe = wireframe
        self.listFactory = listFactory
        self.delegate = delegate
        self.logger = logger
        self.filterSession = filterSession
        sort = filterSession.applied(isRoot: target.isRoot).sort
        self.localizationManager = localizationManager
    }
}

private extension SubtensorValidatorSelectPresenter {
    func provideState() {
        let header = listFactory.createLoadingViewModel(isRoot: target.isRoot, sort: sort, locale: selectedLocale)
        view?.didReceive(
            header: header,
            isFilterActive: filterSession.applied(isRoot: target.isRoot) != .supportedDefault
        )
        if let error = directoryError ?? clientGatesError {
            let viewModel = listFactory.createErrorViewModel(for: error, locale: selectedLocale)
            view?.didReceive(state: .failed(viewModel))
            return
        }

        guard let directory, let clientGates else {
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
            clientGates: clientGates,
            sort: sort,
            query: query,
            selectedHotkey: selectedHotkey,
            preselectedHotkey: preselectedHotkey
        )

        view?.didReceive(state: .loaded(listFactory.createListViewModel(for: input, locale: selectedLocale)))
    }

    func selectableItem(for hotkey: AccountId?) -> SubtensorValidatorDirectoryItem? {
        guard let clientGates else {
            return nil
        }

        return SubtensorValidatorEligibility.selectableItem(
            for: hotkey,
            in: directory,
            isRoot: target.isRoot,
            gates: clientGates
        )
    }

    func handedOut(_ item: SubtensorValidatorDirectoryItem) -> SubtensorValidatorDirectoryItem {
        directory?.listStamp?.freshness == .fresh ? item : item.withoutReportedStake()
    }

    func applyPreselection() {
        guard let directory, let clientGates else {
            return
        }

        selectedHotkey = SubtensorValidatorEligibility.preselectedHotkey(
            selectedHotkey,
            in: directory,
            isRoot: target.isRoot,
            gates: clientGates
        )
        preselectedHotkey = selectedHotkey
    }

    func apply(directory: SubtensorValidatorDirectory) {
        guard directory.subnet.netuid == target.netuid,
              target.isRoot || directory.subnet.registeredAt == target.subnetInfo?.networkRegisteredAt else { return }
        self.directory = directory
        directoryError = nil

        applyPreselection()
    }

    func apply(clientGates: SubtensorClientGates) {
        self.clientGates = clientGates
        clientGatesError = nil

        applyPreselection()
    }

    func seed(from snapshot: SubtensorValidatorSelectSnapshot) {
        if let directory = snapshot.directory.value {
            apply(directory: directory)
        }

        if let clientGates = snapshot.clientGates.value {
            apply(clientGates: clientGates)
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
        clientGates = nil
        clientGatesError = nil

        if !target.isRoot {
            yields = nil
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
            .showFilters(from: view, applied: filterSession.applied(isRoot: target.isRoot)) { [weak self] filters in
                guard let self else { return }
                self.filterSession.apply(filters, isRoot: self.target.isRoot)
                self.sort = self.filterSession.applied(isRoot: self.target.isRoot).sort
                self.provideState()
            }
    }

    func select(hotkey: AccountId) {
        guard selectableItem(for: hotkey) != nil else {
            return
        }

        selectedHotkey = hotkey
        provideState()
    }

    func showInfo(hotkey: AccountId) {
        let item = directory?.items.first { $0.hotkey == hotkey }

        wireframe.showValidatorInfo(
            from: view,
            target: target,
            hotkey: hotkey,
            detail: item.map(handedOut)
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

    func didReceive(clientGates: SubtensorClientGates) {
        apply(clientGates: clientGates)
        provideState()
    }

    func didFailClientGates(_ error: Error) {
        clientGates = nil
        clientGatesError = error
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
}

extension SubtensorValidatorSelectPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            provideState()
        }
    }
}
