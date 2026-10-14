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
        let header = listFactory.createLoadingViewModel(yields: yields, sort: sort, locale: selectedLocale)
        view?.didReceive(
            header: header,
            isFilterActive: filterSession.applied(isRoot: target.isRoot) != .supportedDefault
        )
        if let error = directoryError {
            let viewModel = listFactory.createErrorViewModel(for: error, locale: selectedLocale)
            view?.didReceive(state: .failed(viewModel))
            return
        }

        guard let directory else {
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
            sort: sort,
            query: query,
            selectedHotkey: selectedHotkey,
            preselectedHotkey: preselectedHotkey
        )

        view?.didReceive(state: .loaded(listFactory.createListViewModel(for: input, locale: selectedLocale)))
    }

    func selectableItem(for hotkey: AccountId?) -> SubtensorValidatorDirectoryItem? {
        directory?.items.first { $0.hotkey == hotkey }
    }

    func handedOut(_ item: SubtensorValidatorDirectoryItem) -> SubtensorValidatorDirectoryItem {
        directory?.listStamp?.freshness == .fresh ? item : item.withoutReportedStake()
    }

    func apply(directory: SubtensorValidatorDirectory) {
        guard directory.subnet.netuid == target.netuid,
              target.isRoot || directory.subnet.registeredAt == target.subnetInfo?.networkRegisteredAt else { return }
        self.directory = directory
        directoryError = nil
        selectedHotkey = selectableItem(for: selectedHotkey)?.hotkey
        preselectedHotkey = selectedHotkey
    }

    func seed(from snapshot: SubtensorValidatorSelectSnapshot) {
        if let directory = snapshot.directory.value {
            apply(directory: directory)
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
        wireframe.showValidatorInfo(
            from: view,
            target: target,
            hotkey: hotkey,
            detail: selectableItem(for: hotkey).map(handedOut)
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
}

extension SubtensorValidatorSelectPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            provideState()
        }
    }
}
