import Foundation
import Operation_iOS
import Foundation_iOS

final class TokensManagePresenter {
    weak var view: TokensManageViewProtocol?
    let wireframe: TokensManageWireframeProtocol
    let interactor: TokensManageInteractorInputProtocol
    let viewModelFactory: TokensManageViewModelFactoryProtocol

    private(set) var chains: ListDifferenceCalculator<ChainModel>

    private var groupStyle: AssetListGroupsStyle?
    private var rows: [String: AssetVisibilityLocal]?
    private var defaults: DefaultAssetsList?
    private var hasReceivedChains: Bool = false
    private var query: String = ""
    private var expandedGroupIds: Set<String> = []
    private var listedGroups: [String: TokensManageGroup] = [:]

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

    func buildGroups(style: AssetListGroupsStyle, visibility: AssetVisibility) -> [TokensManageGroup] {
        switch style {
        case .tokens:
            return buildTokenGroups(visibility: visibility)
        case .networks:
            return buildNetworkGroups(visibility: visibility)
        }
    }

    func buildTokenGroups(visibility: AssetVisibility) -> [TokensManageGroup] {
        let syncingChains = chains.allItems.filter { $0.syncMode.enabled() }
        let chainsById = syncingChains.reduce(into: [ChainModel.Id: ChainModel]()) { $0[$1.chainId] = $1 }
        let tokens = filterTokens(syncingChains.createMultichainTokens(), for: query)

        return tokens.map { token in
            let members = token.instances.compactMap { instance in
                createTokenMember(for: instance.chainAssetId, chainsById: chainsById, visibility: visibility)
            }

            return TokensManageGroup(
                id: token.symbol,
                title: token.symbol,
                icon: .asset(token.icon),
                kind: .token,
                isPaused: false,
                members: members
            )
        }
    }

    func createTokenMember(
        for chainAssetId: ChainAssetId,
        chainsById: [ChainModel.Id: ChainModel],
        visibility: AssetVisibility
    ) -> TokensManageMember? {
        guard let chainAsset = chainsById[chainAssetId.chainId]?.chainAsset(for: chainAssetId.assetId) else {
            return nil
        }

        return TokensManageMember(
            chainAssetId: chainAssetId,
            title: chainAsset.chain.name,
            subtitle: nil,
            icon: .chain(chainAsset.chain),
            symbol: chainAsset.asset.symbol,
            chainName: chainAsset.chain.name,
            isVisible: visibility.isVisible(chainAssetId)
        )
    }

    func buildNetworkGroups(visibility: AssetVisibility) -> [TokensManageGroup] {
        chains.allItems.map { chain in
            let members = chain.assets.sorted { $0.assetId < $1.assetId }.map { asset in
                let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)

                return TokensManageMember(
                    chainAssetId: chainAssetId,
                    title: asset.symbol,
                    subtitle: asset.name,
                    icon: .asset(asset.icon),
                    symbol: asset.symbol,
                    chainName: chain.name,
                    isVisible: visibility.isVisible(chainAssetId)
                )
            }

            return TokensManageGroup(
                id: chain.chainId,
                title: chain.name,
                icon: .chain(chain),
                kind: .network,
                isPaused: !chain.syncMode.enabled(),
                members: members
            )
        }
    }

    func sortedSections(
        _ groups: [TokensManageGroup],
        defaults: DefaultAssetsList
    ) -> [TokensManageGroupSection] {
        var rankedDefaults: [(rank: Int, group: TokensManageGroup)] = []
        var others: [TokensManageGroup] = []
        var paused: [TokensManageGroup] = []

        for group in groups {
            let rank = group.members.compactMap { defaults.rank(of: $0.chainAssetId) }.min()

            if group.isPaused {
                paused.append(group)
            } else if let rank {
                rankedDefaults.append((rank, group))
            } else {
                others.append(group)
            }
        }

        let sortedDefaults = rankedDefaults.enumerated().sorted {
            ($0.element.rank, $0.offset) < ($1.element.rank, $1.offset)
        }.map(\.element.group)

        return [
            TokensManageGroupSection(kind: .default, groups: sortedDefaults),
            TokensManageGroupSection(kind: .others, groups: others),
            TokensManageGroupSection(kind: .paused, groups: paused)
        ].filter { !$0.groups.isEmpty }
    }

    func resetView() {
        // clear first
        view?.didReceive(sections: [])

        // and then recreate the items
        updateView()
    }

    func updateView() {
        guard let groupStyle, let visibility, hasReceivedChains else {
            listedGroups = [:]
            view?.didReceive(sections: [])
            return
        }

        let groups = buildGroups(style: groupStyle, visibility: visibility)
        listedGroups = groups.reduce(into: [:]) { $0[$1.id] = $1 }

        let sections = viewModelFactory.createSections(
            from: sortedSections(groups, defaults: visibility.defaults),
            expandedIds: expandedGroupIds,
            locale: selectedLocale
        )

        view?.didReceive(sections: sections)
    }

    func save(chainAssetIds: Set<ChainAssetId>, isOn: Bool) {
        interactor.save(chainAssetIds: chainAssetIds, state: isOn ? .visible : .hidden)
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

    func performExpand(for viewModel: TokensManageRootViewModel) {
        guard let group = listedGroups[viewModel.groupId], group.isExpandable else {
            return
        }

        expandedGroupIds.formSymmetricDifference([group.id])

        updateView()
    }

    func performSwitch(for root: TokensManageRootViewModel, isOn: Bool) {
        guard let group = listedGroups[root.groupId], !group.isPaused else {
            return
        }

        save(chainAssetIds: Set(group.members.map(\.chainAssetId)), isOn: isOn)
    }

    func performSwitch(for child: TokensManageChildViewModel, isOn: Bool) {
        save(chainAssetIds: [child.chainAssetId], isOn: isOn)
    }
}

// MARK: TokensManageInteractorOutputProtocol

extension TokensManagePresenter: TokensManageInteractorOutputProtocol {
    func didReceiveGroupStyle(_ style: AssetListGroupsStyle) {
        groupStyle = style
    }

    func didReceiveChainModel(changes: [DataProviderChange<ChainModel>]) {
        chains.apply(changes: changes)
        hasReceivedChains = true

        updateView()
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
