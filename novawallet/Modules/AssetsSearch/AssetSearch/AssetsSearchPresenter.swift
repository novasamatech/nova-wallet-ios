import Foundation
import BigInt
import RobinHood
import SoraFoundation

typealias ChainAssetsFilter = (ChainAsset) -> Bool

class AssetsSearchPresenter: AssetsSearchPresenterProtocol {
    weak var view: AssetsSearchViewProtocol?
    weak var delegate: AssetsSearchDelegate?
    var chainAssetsFilter: ChainAssetsFilter?

    private(set) var groups: ListDifferenceCalculator<AssetListGroupModel>
    private(set) var groupLists: [ChainModel.Id: ListDifferenceCalculator<AssetListAssetModel>] = [:]

    let wireframe: AssetsSearchWireframeProtocol
    let interactor: AssetsSearchInteractorInputProtocol
    let viewModelFactory: AssetListAssetViewModelFactoryProtocol

    private(set) var state: AssetListState

    private var query: String = ""

    init(
        initState: AssetListState,
        delegate: AssetsSearchDelegate?,
        interactor: AssetsSearchInteractorInputProtocol,
        wireframe: AssetsSearchWireframeProtocol,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        state = initState
        groups = AssetListBuilder.createGroupsDiffCalculator(from: [])
        self.delegate = delegate
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    private func filterAndUpdateView() {
        applyFilter()
        provideAssetsViewModel()
    }

    private func applyFilter() {
        let filteredAssets = filterAssets(for: query, filter: chainAssetsFilter, chains: state.allChains)
        updateGroups(from: filteredAssets, allChains: state.allChains)
    }

    private func updateGroups(from assets: [ChainAsset], allChains: [ChainModel.Id: ChainModel]) {
        let assetModels = assets.reduce(into: [ChainModel.Id: [AssetListAssetModel]]()) { result, chainAsset in
            let assetModel = AssetListBaseBuilder.createAssetModel(
                for: chainAsset.chain,
                assetModel: chainAsset.asset,
                state: state
            )

            let currentModels = result[chainAsset.chain.chainId] ?? []
            result[chainAsset.chain.chainId] = currentModels + [assetModel]
        }

        let groupAssetCalculators = assetModels.mapValues { models in
            AssetListBuilder.createAssetsDiffCalculator(from: models)
        }

        let chainModels: [AssetListGroupModel] = assetModels.compactMap { chainId, assetModels in
            guard let chain = allChains[chainId] else {
                return nil
            }

            return AssetListBaseBuilder.createGroupModel(from: chain, assets: assetModels)
        }

        let groupChainCalculator = AssetListBuilder.createGroupsDiffCalculator(from: chainModels)

        groups = groupChainCalculator
        groupLists = groupAssetCalculators
    }

    private func filterAssets(
        for query: String,
        filter: ChainAssetsFilter?,
        chains: [ChainModel.Id: ChainModel]
    ) -> [ChainAsset] {
        var chainAssets = chains.values.flatMap { chain in
            chain.assets.map { ChainAsset(chain: chain, asset: $0) }
        }

        if let filter = filter {
            chainAssets = chainAssets.filter(filter)
        }

        guard !query.isEmpty else {
            return chainAssets
        }

        let allAssetsMatching = chainAssets.compactMap { chainAsset in
            SearchMatch<ChainAsset>.matchString(for: query, recordField: chainAsset.asset.symbol, record: chainAsset)
        }

        let allMatchedAssets = allAssetsMatching.map(\.item)

        if allAssetsMatching.contains(where: { $0.isFull }) {
            return allMatchedAssets
        }

        let matchedChainAssetsIds = Set(allMatchedAssets.map(\.chainAssetId))

        var allMatchedChains = chains.values.reduce(into: [ChainAsset]()) { result, chain in
            let match = SearchMatch<ChainAsset>.matchInclusion(
                for: query,
                recordField: chain.name,
                record: chain
            )

            guard match != nil else {
                return
            }

            chain.assets.forEach { asset in
                let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)

                if !matchedChainAssetsIds.contains(chainAssetId) {
                    let chainAsset = ChainAsset(chain: chain, asset: asset)
                    result.append(chainAsset)
                }
            }
        }

        if let filter = filter {
            allMatchedChains = allMatchedChains.filter(filter)
        }

        return allMatchedAssets + allMatchedChains
    }

    private func provideAssetsViewModel() {
        let maybePrices = try? state.priceResult?.get()

        let viewModels: [AssetListGroupViewModel] = groups.allItems.compactMap { groupModel in
            createGroupViewModel(from: groupModel, maybePrices: maybePrices)
        }

        if viewModels.isEmpty, !state.balanceResults.isEmpty, state.balanceResults.count >= state.allChains.count {
            view?.didReceiveGroups(state: .empty)
        } else {
            view?.didReceiveGroups(state: .list(groups: viewModels))
        }
    }

    private func createGroupViewModel(
        from groupModel: AssetListGroupModel,
        maybePrices: [ChainAssetId: PriceData]?
    ) -> AssetListGroupViewModel? {
        let chain = groupModel.chain

        let assets = groupLists[chain.chainId]?.allItems ?? []

        let assetInfoList: [AssetListAssetAccountInfo] = assets.map { asset in
            createAssetAccountInfo(from: asset, chain: chain, maybePrices: maybePrices)
        }

        return viewModelFactory.createGroupViewModel(
            for: chain,
            assets: assetInfoList,
            value: groupModel.chainValue,
            connected: true,
            locale: selectedLocale
        )
    }

    private func createAssetAccountInfo(
        from asset: AssetListAssetModel,
        chain: ChainModel,
        maybePrices: [ChainAssetId: PriceData]?
    ) -> AssetListAssetAccountInfo {
        let assetModel = asset.assetModel
        let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: assetModel.assetId)

        let assetInfo = assetModel.displayInfo

        let priceData: PriceData?

        if let prices = maybePrices {
            priceData = prices[chainAssetId] ?? PriceData.zero()
        } else {
            priceData = nil
        }

        return AssetListAssetAccountInfo(
            assetId: asset.assetModel.assetId,
            assetInfo: assetInfo,
            balance: asset.totalAmount,
            priceData: priceData
        )
    }

    // MARK: - AssetsSearchPresenterProtocol

    func setup() {
        filterAndUpdateView()

        interactor.setup()
    }

    func selectAsset(for chainAssetId: ChainAssetId) {
        delegate?.assetSearchDidSelect(chainAssetId: chainAssetId)

        wireframe.close(view: view)
    }

    func updateSearch(query: String) {
        self.query = query

        filterAndUpdateView()
    }

    func cancel() {
        wireframe.close(view: view)
    }
}

extension AssetsSearchPresenter: AssetsSearchInteractorOutputProtocol {
    func didReceive(state: AssetListState) {
        self.state = state

        filterAndUpdateView()
    }
}

extension AssetsSearchPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideAssetsViewModel()
        }
    }
}
