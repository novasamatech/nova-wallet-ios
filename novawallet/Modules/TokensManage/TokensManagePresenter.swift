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

    private var query: String = ""

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

    private func filterTokens(_ tokens: [MultichainToken], for query: String) -> [MultichainToken] {
        guard !query.isEmpty else {
            return tokens
        }

        let allTokensMatching = tokens.compactMap { token in
            SearchMatch<MultichainToken>.matchString(for: query, recordField: token.symbol, record: token)
        }

        let allMatchedTokens = allTokensMatching.map(\.item)

        if allTokensMatching.contains(where: { $0.isFull }) {
            return allMatchedTokens
        }

        let matchedSymbols = Set(allMatchedTokens.map(\.symbol))

        let allMatchedChains = tokens.filter { token in
            let hasChainMatch = token.instances.contains { instance in
                let match = SearchMatch<MultichainToken.Instance>.matchInclusion(
                    for: query,
                    recordField: instance.chainName,
                    record: instance
                )

                return match != nil
            }

            return hasChainMatch && !matchedSymbols.contains(token.symbol)
        }

        return allMatchedTokens + allMatchedChains
    }

    private func updateView() {
        let filteredTokens = filterTokens(tokenModels, for: query)

        let viewModels = filteredTokens.map {
            viewModelFactory.createViewModel(from: $0, locale: selectedLocale)
        }

        view?.didReceive(viewModels: viewModels)
    }
}

extension TokensManagePresenter: TokensManagePresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func search(query: String) {
        self.query = query

        updateView()
    }

    func performAddToken() {}

    func performEdit(for _: TokensManageViewModel) {}

    func performSwitch(for _: TokensManageViewModel, isOn _: Bool) {}
}

extension TokensManagePresenter: TokensManageInteractorOutputProtocol {
    func didReceiveChainModel(changes: [DataProviderChange<ChainModel>]) {
        chains.apply(changes: changes)

        tokenModels = chains.allItems.createMultichainTokens()

        updateView()
    }
}

extension TokensManagePresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
