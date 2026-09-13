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

    private var groupStyle: AssetListGroupsStyle?
    private var rows: [String: AssetVisibilityLocal]?
    private var defaults: DefaultAssetsList?
    private var query: String = ""

    private var visibility: AssetVisibility? {
        guard let rows, let defaults else {
            return nil
        }

        let states = rows.values.reduce(into: [ChainAssetId: AssetVisibilityState]()) { accum, row in
            accum[row.chainAssetId] = row.state
        }

        return AssetVisibility(defaults: defaults, rows: states)
    }

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
}

// MARK: Private

private extension TokensManagePresenter {
    func reloadTokens() {
        tokenModels = chains.allItems.filter { $0.syncMode.enabled() }.createMultichainTokens()

        updateView()
    }

    func filterTokens(_ tokens: [MultichainToken], for query: String) -> [MultichainToken] {
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

    func resetView() {
        // clear first
        view?.didReceive(viewModels: [])

        // and then recreate the items
        updateView()
    }

    func updateView() {
        guard let visibility else {
            view?.didReceive(viewModels: [])
            return
        }

        let filteredTokens = filterTokens(tokenModels, for: query)

        let viewModels = filteredTokens.map {
            viewModelFactory.createListViewModel(from: $0, visibility: visibility, locale: selectedLocale)
        }

        view?.didReceive(viewModels: viewModels)
    }
}

// MARK: TokensManagePresenterProtocol

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

    func performSwitch(for viewModel: TokensManageViewModel, enabled: Bool) {
        guard let token = tokenModels.first(where: { $0.symbol == viewModel.symbol }) else {
            return
        }

        let chainAssetIds = Set(token.instances.map(\.chainAssetId))

        interactor.save(chainAssetIds: chainAssetIds, state: enabled ? .visible : .hidden)
    }
}

// MARK: TokensManageInteractorOutputProtocol

extension TokensManagePresenter: TokensManageInteractorOutputProtocol {
    func didReceiveGroupStyle(_ style: AssetListGroupsStyle) {
        groupStyle = style
    }

    func didReceiveChainModel(changes: [DataProviderChange<ChainModel>]) {
        chains.apply(changes: changes)

        reloadTokens()
    }

    func didReceiveVisibility(changes: [DataProviderChange<AssetVisibilityLocal>]) {
        rows = changes.mergeToDict(rows ?? [:])

        updateView()
    }

    func didReceiveAutoAddTokens(enabled _: Bool) {}

    func didReceiveDefaultAssets(_ list: DefaultAssetsList) {
        defaults = list

        updateView()
    }

    func didFailSave() {
        resetView()
    }
}

// MARK: Localizable

extension TokensManagePresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
