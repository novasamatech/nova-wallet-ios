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
    private var autoAddTokens: Bool?
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
    func applySearch(to sections: [TokensManageGroupSection]) -> [TokensManageGroupSection] {
        guard !query.isEmpty else {
            return sections
        }

        let groups = sections.flatMap(\.groups).compactMap { searchGroup($0) }

        return [TokensManageGroupSection(kind: .results, groups: groups)]
    }

    func searchGroup(_ group: TokensManageGroup) -> TokensManageGroup? {
        let members = group.members.filter { isMatchingQuery($0) }

        guard !members.isEmpty else {
            return nil
        }

        return TokensManageGroup(
            id: group.id,
            title: group.title,
            icon: group.icon,
            kind: group.kind,
            isPaused: group.isPaused,
            members: members
        )
    }

    func isMatchingQuery(_ member: TokensManageMember) -> Bool {
        let symbolMatch = SearchMatch.matchString(for: query, recordField: member.symbol, record: member)
        let chainMatch = SearchMatch.matchInclusion(for: query, recordField: member.chainName, record: member)

        return symbolMatch != nil || chainMatch != nil
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

        return syncingChains.createMultichainTokens().map { token in
            let membersPerChain = token.instances.reduce(into: [ChainModel.Id: Int]()) { counts, instance in
                counts[instance.chainAssetId.chainId, default: 0] += 1
            }

            let members = token.instances.compactMap { instance in
                createTokenMember(
                    for: instance.chainAssetId,
                    groupSymbol: token.symbol,
                    sharesChain: membersPerChain[instance.chainAssetId.chainId, default: 0] > 1,
                    chainsById: chainsById,
                    visibility: visibility
                )
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
        groupSymbol: String,
        sharesChain: Bool,
        chainsById: [ChainModel.Id: ChainModel],
        visibility: AssetVisibility
    ) -> TokensManageMember? {
        guard let chainAsset = chainsById[chainAssetId.chainId]?.chainAsset(for: chainAssetId.assetId) else {
            return nil
        }

        let variantSymbol = MultichainToken.variantSymbol(
            of: chainAsset.asset.symbol,
            inGroupWith: groupSymbol,
            sharingChainWithSiblings: sharesChain
        )

        return TokensManageMember(
            chainAssetId: chainAssetId,
            title: chainAsset.chain.name,
            subtitle: variantSymbol,
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

    func listedMembers() -> [TokensManageMember] {
        listedGroups.values.filter { !$0.isPaused }.flatMap(\.members)
    }

    func createHeaderAction() -> TokensManageHeaderActionViewModel {
        let members = listedMembers()

        guard !members.isEmpty else {
            return TokensManageHeaderActionViewModel(kind: .selectAll, isEnabled: false)
        }

        let hasHiddenMember = members.contains { !$0.isVisible }

        return TokensManageHeaderActionViewModel(
            kind: hasHiddenMember ? .selectAll : .deselectAll,
            isEnabled: true
        )
    }

    func resetView() {
        // clear first
        view?.didReceive(sections: [])

        // and then recreate the items
        updateView()

        if let autoAddTokens {
            view?.didReceive(autoAddTokens: autoAddTokens)
        }
    }

    func updateView() {
        guard let groupStyle, let visibility, hasReceivedChains else {
            listedGroups = [:]
            view?.didReceive(sections: [])
            view?.didReceive(headerAction: createHeaderAction())
            return
        }

        let groups = buildGroups(style: groupStyle, visibility: visibility)
        let sections = applySearch(to: sortedSections(groups, defaults: visibility.defaults))
        listedGroups = sections.flatMap(\.groups).reduce(into: [:]) { $0[$1.id] = $1 }

        let viewModels = viewModelFactory.createSections(
            from: sections,
            expandedIds: expandedGroupIds,
            locale: selectedLocale
        )

        view?.didReceive(sections: viewModels)
        view?.didReceive(headerAction: createHeaderAction())
    }

    func save(chainAssetIds: Set<ChainAssetId>, isOn: Bool) {
        interactor.save(chainAssetIds: chainAssetIds, isVisible: isOn)
    }

    func saveListedMembers(isOn: Bool) {
        let chainAssetIds = Set(listedMembers().map(\.chainAssetId))

        guard !chainAssetIds.isEmpty else {
            return
        }

        save(chainAssetIds: chainAssetIds, isOn: isOn)
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

    func performSelectAll() {
        saveListedMembers(isOn: true)
    }

    func performDeselectAll() {
        saveListedMembers(isOn: false)
    }

    func performAutoAddChange(to isOn: Bool) {
        interactor.save(autoAddTokensWithBalance: isOn)
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

    func didReceiveAutoAddTokens(enabled: Bool) {
        autoAddTokens = enabled

        view?.didReceive(autoAddTokens: enabled)
    }

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
