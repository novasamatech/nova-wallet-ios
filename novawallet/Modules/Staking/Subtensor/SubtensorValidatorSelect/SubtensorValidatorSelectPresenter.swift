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
    private var clientGates: SubtensorClientGates = .backendDefault
    private var yields: SubtensorAlphaYields?
    private var hasYieldsAnswer: Bool
    private var alphaPrice: Balance?
    private var hasAlphaPriceAnswer: Bool
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
        logger: LoggerProtocol
    ) {
        self.target = target
        self.selectedHotkey = selectedHotkey
        self.interactor = interactor
        self.wireframe = wireframe
        self.listFactory = listFactory
        self.delegate = delegate
        self.logger = logger
        sort = target.isRoot ? .totalStaked : .apy
        hasYieldsAnswer = target.isRoot
        hasAlphaPriceAnswer = target.isRoot
        self.localizationManager = localizationManager
    }
}

private extension SubtensorValidatorSelectPresenter {
    var answeredYields: SubtensorAlphaYields? {
        hasYieldsAnswer ? yields : nil
    }

    func provideState() {
        if let directoryError {
            let viewModel = listFactory.createErrorViewModel(for: directoryError, locale: selectedLocale)
            view?.didReceive(state: .failed(viewModel))
            return
        }

        guard let directory, hasYieldsAnswer, hasAlphaPriceAnswer else {
            view?.didReceive(
                state: .loading(listFactory.createLoadingViewModel(isRoot: target.isRoot, locale: selectedLocale))
            )
            return
        }

        let input = SubtensorValidatorListInput(
            directory: directory,
            yields: yields,
            alphaPrice: alphaPrice,
            isRoot: target.isRoot,
            maxTake: clientGates.maxTake,
            sort: sort,
            query: query,
            selectedHotkey: selectedHotkey,
            preselectedHotkey: preselectedHotkey
        )

        view?.didReceive(state: .loaded(listFactory.createListViewModel(for: input, locale: selectedLocale)))
    }

    func selectableItem(for hotkey: AccountId?) -> SubtensorValidatorDirectoryItem? {
        SubtensorValidatorListFactory.selectableItem(
            for: hotkey,
            in: directory,
            isRoot: target.isRoot,
            maxTake: clientGates.maxTake
        )
    }
}

extension SubtensorValidatorSelectPresenter: ValidatorSelectPresenterProtocol {
    func setup() {
        provideState()
        interactor.setup()
    }

    func retry() {
        directory = nil
        directoryError = nil

        if !target.isRoot {
            yields = nil
            hasYieldsAnswer = false
            alphaPrice = nil
            hasAlphaPriceAnswer = false
        }

        provideState()
        interactor.retry()
    }

    func search(_ query: String) {
        self.query = query
        provideState()
    }

    func showSortOptions() {
        let options = SubtensorValidatorListFactory.sortOptions(isRoot: target.isRoot, yields: answeredYields)
        let applied = SubtensorValidatorListFactory.appliedSort(sort, isRoot: target.isRoot, yields: answeredYields)

        let viewModel = listFactory.createSortSheetViewModel(
            options: options,
            selected: applied,
            locale: selectedLocale
        )

        wireframe.showSortSheet(from: view, viewModel: viewModel) { [weak self] index in
            guard options.indices.contains(index) else {
                return
            }

            self?.sort = options[index]
            self?.provideState()
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
            detail: item.map { SubtensorValidatorDetail(item: $0, identity: nil) }
        )
    }

    func confirm() {
        guard let item = selectableItem(for: selectedHotkey) else {
            return
        }

        delegate?.didSelectValidator(item, for: target)
        wireframe.complete(from: view)
    }
}

extension SubtensorValidatorSelectPresenter: ValidatorSelectInteractorOutputProtocol {
    func didReceive(directory: SubtensorValidatorDirectory, clientGates: SubtensorClientGates) {
        self.directory = directory
        self.clientGates = clientGates
        directoryError = nil

        selectedHotkey = SubtensorValidatorListFactory.preselectedHotkey(
            selectedHotkey,
            in: directory,
            isRoot: target.isRoot,
            maxTake: clientGates.maxTake
        )
        preselectedHotkey = selectedHotkey

        provideState()
    }

    func didFailDirectory(_ error: Error) {
        directory = nil
        directoryError = error
        provideState()
    }

    func didReceive(yields: SubtensorAlphaYields?) {
        self.yields = yields
        hasYieldsAnswer = true
        provideState()
    }

    func didReceive(alphaPrice: Balance?) {
        self.alphaPrice = alphaPrice
        hasAlphaPriceAnswer = true
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
