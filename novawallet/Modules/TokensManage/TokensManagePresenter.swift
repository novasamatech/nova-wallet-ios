import Foundation
import RobinHood

final class TokensManagePresenter {
    weak var view: TokensManageViewProtocol?
    let wireframe: TokensManageWireframeProtocol
    let interactor: TokensManageInteractorInputProtocol

    private(set) var chains: ListDifferenceCalculator<ChainModel>
    private(set) var tokenModels: [MultichainToken] = []

    init(
        interactor: TokensManageInteractorInputProtocol,
        wireframe: TokensManageWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe

        let sortingBlock: (ChainModel, ChainModel) -> Bool = { model1, model2 in
            ChainModelCompator.defaultComparator(chain1: model1, chain2: model2)
        }

        chains = ListDifferenceCalculator(initialItems: [], sortBlock: sortingBlock)
    }
}

extension TokensManagePresenter: TokensManagePresenterProtocol {
    func setup() {}

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
