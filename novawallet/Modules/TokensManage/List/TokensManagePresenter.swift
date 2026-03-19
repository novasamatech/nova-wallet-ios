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
    private(set) var dustFilterEnabled: Bool = false
    private(set) var dustFilterThreshold: Decimal = 1.0

    private var currentTab: ManageTokensTab = .tokens
    private var expandedIndex: Int?
    private var query: String = ""

    private var isDefaultFilterActive: Bool = false
    private var defaultTokenIds: Set<ChainAssetId> = []
    private var userAddedTokenIds: Set<ChainAssetId> = []

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

    private func filterChains(_ allChains: [ChainModel], for query: String) -> [ChainModel] {
        guard !query.isEmpty else {
            return allChains
        }

        return allChains.filter { chain in
            let chainMatch = SearchMatch<ChainModel>.matchInclusion(
                for: query,
                recordField: chain.name,
                record: chain
            )

            if chainMatch != nil {
                return true
            }

            let hasAssetMatch = chain.assets.contains { asset in
                let assetMatch = SearchMatch<AssetModel>.matchInclusion(
                    for: query,
                    recordField: asset.symbol,
                    record: asset
                )
                return assetMatch != nil
            }

            return hasAssetMatch
        }
    }

    private func resetView() {
        view?.didReceive(sections: [])

        updateView()
    }

    private func currentSections() -> [ManageTokenSection] {
        let sections: [ManageTokenSection]

        switch currentTab {
        case .tokens:
            let filteredTokens = filterTokens(tokenModels, for: query)
            sections = viewModelFactory.createTokenSections(
                from: filteredTokens,
                chains: chains.allItems,
                expandedIndex: expandedIndex,
                locale: selectedLocale
            )
        case .networks:
            let filteredChains = filterChains(chains.allItems, for: query)
            sections = viewModelFactory.createNetworkSections(
                from: filteredChains,
                expandedIndex: expandedIndex,
                locale: selectedLocale
            )
        }

        guard isDefaultFilterActive else {
            return sections
        }

        // When default filter is active, override isEnabled to show visual state
        let visibleIds = defaultTokenIds.union(userAddedTokenIds)

        return sections.map { section in
            let overriddenItems = section.items.map { item in
                ManageTokenItem(
                    chainAssetId: item.chainAssetId,
                    name: item.name,
                    icon: item.icon,
                    isEnabled: visibleIds.contains(item.chainAssetId)
                )
            }
            let enabledCount = overriddenItems.filter(\.isEnabled).count
            return ManageTokenSection(
                title: section.title,
                icon: section.icon,
                items: overriddenItems,
                isExpanded: section.isExpanded,
                enabledCount: enabledCount
            )
        }
    }

    private func updateView() {
        let sections = currentSections()

        view?.didReceive(sections: sections)

        updateSelectAllTitle(for: sections)
    }

    private func updateSelectAllTitle(for sections: [ManageTokenSection]) {
        let allItems = sections.flatMap(\.items)
        let allEnabled = !allItems.isEmpty && allItems.allSatisfy(\.isEnabled)
        let languages = selectedLocale.rLanguages
        let hasSearch = !query.isEmpty

        let title: String

        if allEnabled {
            title = hasSearch
                ? R.string(preferredLanguages: languages).localizable.commonDeselectVisible()
                : R.string(preferredLanguages: languages).localizable.stakingCustomDeselectButtonTitle()
        } else {
            title = hasSearch
                ? R.string(preferredLanguages: languages).localizable.commonSelectVisible()
                : R.string(preferredLanguages: languages).localizable.commonSelectAll()
        }

        view?.didReceive(selectAllTitle: title)
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
        // Load default filter state — use a callback since defaultTokenIds may not be loaded yet
        interactor.fetchDefaultFilterState { [weak self] isActive, defaults, userAdded in
            self?.isDefaultFilterActive = isActive
            self?.defaultTokenIds = defaults
            self?.userAddedTokenIds = userAdded
            self?.updateView()
        }

        interactor.setup()
    }

    func search(query: String) {
        self.query = query
        expandedIndex = nil

        updateView()
    }

    func performAddToken() {
        wireframe.showAddToken(from: view)
    }

    func performTabSwitch(to tab: ManageTokensTab) {
        guard currentTab != tab else {
            return
        }

        currentTab = tab
        expandedIndex = nil

        updateView()
    }

    func performToggleSection(at index: Int) {
        if expandedIndex == index {
            expandedIndex = nil
        } else {
            expandedIndex = index
        }

        updateView()
    }

    func performSwitch(for item: ManageTokenItem, enabled: Bool) {
        if isDefaultFilterActive {
            // When default filter is active, toggle user-added set instead of DB
            if enabled {
                if !defaultTokenIds.contains(item.chainAssetId) {
                    interactor.addUserAddedToken(item.chainAssetId)
                    userAddedTokenIds.insert(item.chainAssetId)
                }
            } else {
                if userAddedTokenIds.contains(item.chainAssetId) {
                    interactor.removeUserAddedToken(item.chainAssetId)
                    userAddedTokenIds.remove(item.chainAssetId)
                }
                // Default tokens can be visually toggled off by not being in user-added;
                // but defaults stay shown unless explicitly removed — we don't remove defaults
            }
            updateView()
        } else {
            interactor.save(
                chainAssetIds: [item.chainAssetId],
                enabled: enabled,
                allChains: chains.allItems
            )
        }
    }

    func performSelectAll() {
        let sections = currentSections()

        let allItems = sections.flatMap(\.items)
        let allEnabled = !allItems.isEmpty && allItems.allSatisfy(\.isEnabled)
        let targetEnabled = !allEnabled

        if isDefaultFilterActive {
            // When default filter is active, toggle user-added set
            if targetEnabled {
                for item in allItems where !item.isEnabled {
                    if !defaultTokenIds.contains(item.chainAssetId) {
                        interactor.addUserAddedToken(item.chainAssetId)
                        userAddedTokenIds.insert(item.chainAssetId)
                    }
                }
            } else {
                // Remove all user-added tokens (defaults stay)
                for item in allItems where userAddedTokenIds.contains(item.chainAssetId) {
                    interactor.removeUserAddedToken(item.chainAssetId)
                    userAddedTokenIds.remove(item.chainAssetId)
                }
            }
            updateView()
        } else if !targetEnabled {
            // Show confirmation dialog before deselecting all
            let deselectAction = AlertPresentableAction(
                title: R.string(preferredLanguages: selectedLocale.rLanguages).localizable
                    .stakingCustomDeselectButtonTitle(),
                style: .destructive
            ) { [weak self] in
                self?.executeDeselectAll(allItems: allItems)
            }

            let cancelAction = AlertPresentableAction(
                title: R.string(preferredLanguages: selectedLocale.rLanguages).localizable
                    .commonCancel(),
                style: .cancel
            )

            let viewModel = AlertPresentableViewModel(
                title: R.string(preferredLanguages: selectedLocale.rLanguages).localizable
                    .stakingCustomDeselectButtonTitle(),
                message: R.string(preferredLanguages: selectedLocale.rLanguages).localizable
                    .tokensManageDeselectAllMessage(),
                actions: [cancelAction, deselectAction],
                closeAction: nil
            )

            wireframe.present(
                viewModel: viewModel,
                style: .alert,
                from: view
            )
        } else {
            let chainAssetIds = Set(allItems.map(\.chainAssetId))

            interactor.save(
                chainAssetIds: chainAssetIds,
                enabled: true,
                allChains: chains.allItems
            )
        }
    }

    private func executeDeselectAll(allItems: [ManageTokenItem]) {
        let keepEnabled = ChainAssetId(chainId: KnowChainId.polkadotAssetHub, assetId: 0)
        let chainAssetIds = Set(allItems.map(\.chainAssetId)).filter { $0 != keepEnabled }

        interactor.save(
            chainAssetIds: chainAssetIds,
            enabled: false,
            allChains: chains.allItems
        )

        // Notify the user that at least one token was kept enabled
        wireframe.present(
            message: R.string(preferredLanguages: selectedLocale.rLanguages).localizable
                .tokensManageDeselectAllKeptMessage(),
            title: nil,
            closeAction: R.string(preferredLanguages: selectedLocale.rLanguages).localizable
                .commonOk(),
            from: view
        )
    }

    func performFilterChange(to value: Bool) {
        interactor.save(hideZeroBalances: value)
    }

    func performDustFilterChange(to value: Bool) {
        interactor.save(dustFilterEnabled: value)
    }

    func performDustThresholdChange(to value: Decimal) {
        interactor.save(dustFilterThreshold: value)
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

    func didReceive(dustFilterEnabled: Bool, threshold: Decimal) {
        self.dustFilterEnabled = dustFilterEnabled
        dustFilterThreshold = threshold

        view?.didReceive(dustFilterEnabled: dustFilterEnabled)
        view?.didReceive(dustFilterThreshold: threshold)
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
