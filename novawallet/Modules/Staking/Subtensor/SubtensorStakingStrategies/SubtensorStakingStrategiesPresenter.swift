import Foundation
import Foundation_iOS

final class SubtensorStakingStrategiesPresenter {
    weak var view: SubtensorStakingStrategiesViewProtocol?

    let interactor: SubtensorStakingStrategiesInteractorInputProtocol
    let wireframe: SubtensorStakingStrategiesWireframeProtocol
    let viewModelFactory: SubtensorStakingStrategiesViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    private var strategies: [SubtensorStakingStrategy] = []
    private var selectedIndex = 0

    init(
        interactor: SubtensorStakingStrategiesInteractorInputProtocol,
        wireframe: SubtensorStakingStrategiesWireframeProtocol,
        viewModelFactory: SubtensorStakingStrategiesViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }
}

private extension SubtensorStakingStrategiesPresenter {
    func provideViewModel() {
        guard !strategies.isEmpty else {
            return
        }

        let viewModel = viewModelFactory.createViewModel(
            from: strategies,
            locale: localizationManager.selectedLocale
        )

        view?.didReceive(viewModel: .loaded(value: viewModel))
        updateSelection(to: selectedIndex, animated: false)
    }

    func updateSelection(to index: Int, animated: Bool) {
        guard strategies.indices.contains(index) else {
            return
        }

        selectedIndex = index
        view?.didReceive(selectedIndex: index, animated: animated)
    }
}

extension SubtensorStakingStrategiesPresenter: SubtensorStakingStrategiesPresenterProtocol {
    func setup() {
        view?.didReceive(viewModel: .loading)
        interactor.setup()
    }

    func refreshContent() {
        provideViewModel()
    }

    func selectPrevious() {
        updateSelection(to: max(selectedIndex - 1, 0), animated: true)
    }

    func selectNext() {
        updateSelection(to: min(selectedIndex + 1, strategies.count - 1), animated: true)
    }

    func select(index: Int) {
        updateSelection(to: index, animated: false)
    }

    func chooseSelected() {
        guard strategies.indices.contains(selectedIndex) else {
            return
        }

        wireframe.showStakingSetup(
            from: view,
            strategy: strategies[selectedIndex]
        )
    }
}

extension SubtensorStakingStrategiesPresenter: SubtensorStakingStrategiesInteractorOutputProtocol {
    func didReceive(strategies: [SubtensorStakingStrategy]) {
        self.strategies = strategies

        let balancedIndex = strategies.firstIndex(where: { $0.kind == .balanced }) ?? 0
        selectedIndex = balancedIndex

        provideViewModel()
    }

    func didReceive(error _: Error) {
        wireframe.presentLoadError(from: view) { [weak self] in
            self?.interactor.retry()
        }
    }
}
