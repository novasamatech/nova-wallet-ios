import Foundation
import Operation_iOS
import Foundation_iOS

final class TokensManagePresenter {
    weak var view: TokensManageViewProtocol?
    let wireframe: TokensManageWireframeProtocol
    let interactor: TokensManageInteractorInputProtocol
    let viewModelFactory: TokensManageViewModelFactoryProtocol

    private(set) var chains: ListDifferenceCalculator<ChainModel>
    private(set) var tokenModels: [MultichainToken] = []
    private(set) var hideZeroBalances: Bool = false

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

    private func reloadTokens() {
        tokenModels = chains.allItems.createMultichainTokens()

        updateView()
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

    private func resetView() {
        // clear first
        view?.didReceive(viewModels: [])

        // and then recreate the items
        updateView()
    }

    private func updateView() {
        let filteredTokens = filterTokens(tokenModels, for: query)

        let viewModels = filteredTokens.map {
            viewModelFactory.createListViewModel(from: $0, locale: selectedLocale)
        }

        view?.didReceive(viewModels: viewModels)
    }

    private func saveChains(for token: MultichainToken, enabled: Bool) {
        let chainAssetIds = token.instances.map(\.chainAssetId)
        interactor.save(chainAssetIds: Set(chainAssetIds), enabled: enabled, allChains: chains.allItems)
    }

    private func changeHideZeroBalances(to value: Bool) {
        guard hideZeroBalances != value else {
            return
        }

        hideZeroBalances = value

        view?.didReceive(hidesZeroBalances: value)
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

    func performAddToken() {
        wireframe.showAddToken(from: view)
    }

    func performEdit(for viewModel: TokensManageViewModel) {
        guard let token = tokenModels.first(where: { $0.symbol == viewModel.symbol }) else {
            return
        }

        let allChains = chains.allItems.reduceToDict()

        wireframe.showEditToken(from: view, token: token, allChains: allChains)
    }

    func performSwitch(for viewModel: TokensManageViewModel, enabled: Bool) {
        guard let tokenIndex = tokenModels.firstIndex(where: { $0.symbol == viewModel.symbol }) else {
            return
        }

        saveChains(for: tokenModels[tokenIndex], enabled: enabled)
    }

    func performFilterChange(to value: Bool) {
        interactor.save(hideZeroBalances: value)
    }
}

extension TokensManagePresenter: TokensManageInteractorOutputProtocol {
    func didReceiveChainModel(changes: [DataProviderChange<ChainModel>]) {
        chains.apply(changes: changes)

        reloadTokens()
    }

    func didReceive(hideZeroBalances: Bool) {
        changeHideZeroBalances(to: hideZeroBalances)
    }

    func didFailChainSave() {
        resetView()
    }
}

extension TokensManagePresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
