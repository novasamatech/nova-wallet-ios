import Foundation
import RobinHood
import SoraFoundation

final class TokensManagePresenter {
    weak var view: TokensManageViewProtocol?
    let wireframe: TokensManageWireframeProtocol
    let interactor: TokensManageInteractorInputProtocol
    let viewModelFactory: TokensManageViewModelFactoryProtocol

    private(set) var chains: ListDifferenceCalculator<ChainModel>
    private(set) var tokenModels: [MultichainToken] = []

    init(
        interactor: TokensManageInteractorInputProtocol,
        wireframe: TokensManageWireframeProtocol,
        viewModelFactory: TokensManageViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory

        let sortingBlock: (ChainModel, ChainModel) -> Bool = { model1, model2 in
            ChainModelCompator.defaultComparator(chain1: model1, chain2: model2)
        }

        chains = ListDifferenceCalculator(initialItems: [], sortBlock: sortingBlock)

        self.localizationManager = localizationManager
    }

    func updateView() {
        let viewModels = tokenModels.map {
            viewModelFactory.createViewModel(from: $0, locale: selectedLocale)
        }

        view?.didReceive(viewModels: viewModels)
    }
}

extension TokensManagePresenter: TokensManagePresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func performAddToken() {}

    func performEdit(for _: TokensManageViewModel) {}

    func performSwitch(for _: TokensManageViewModel, isOn _: Bool) {}
}

extension TokensManagePresenter: TokensManageInteractorOutputProtocol {
    func didReceiveChainModel(changes: [DataProviderChange<ChainModel>]) {
        chains.apply(changes: changes)

        tokenModels = chains.allItems.createMultichainTokens()
    }
}

extension TokensManagePresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
