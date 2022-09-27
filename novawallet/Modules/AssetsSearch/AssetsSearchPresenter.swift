import Foundation
import BigInt
import RobinHood
import SoraFoundation

final class AssetsSearchPresenter: AssetListBasePresenter {
    weak var view: AssetsSearchViewProtocol?
    weak var delegate: AssetsSearchDelegate?

    let wireframe: AssetsSearchWireframeProtocol
    let interactor: AssetsSearchInteractorInputProtocol
    let viewModelFactory: AssetListAssetViewModelFactoryProtocol

    private var query: String = ""

    init(
        initState: AssetListInitState,
        delegate: AssetsSearchDelegate,
        interactor: AssetsSearchInteractorInputProtocol,
        wireframe: AssetsSearchWireframeProtocol,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.delegate = delegate
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory

        super.init()

        self.localizationManager = localizationManager

        applyInitState(initState)
    }

    private func filterAndUpdateView() {
        applyFilter()
        provideAssetsViewModel()
    }

    private func applyFilter() {
        let filteredAssets = filterAssets(for: query, chains: allChains)
        updateGroups(from: filteredAssets, allChains: allChains)
    }

    private func updateGroups(from assets: [ChainAsset], allChains: [ChainModel.Id: ChainModel]) {
        let assetModels = assets.reduce(into: [ChainModel.Id: [AssetListAssetModel]]()) { result, chainAsset in
            let assetModel = createAssetModel(for: chainAsset.chain, assetModel: chainAsset.asset)
            let currentModels = result[chainAsset.chain.chainId] ?? []
            result[chainAsset.chain.chainId] = currentModels + [assetModel]
        }

        let groupAssetCalculators = assetModels.mapValues { models in
            Self.createAssetsDiffCalculator(from: models)
        }

        let chainModels: [AssetListGroupModel] = assetModels.compactMap { chainId, assetModels in
            guard let chain = allChains[chainId] else {
                return nil
            }

            return createGroupModel(from: chain, assets: assetModels)
        }

        let groupChainCalculator = Self.createGroupsDiffCalculator(from: chainModels)

        storeGroups(groupChainCalculator, groupLists: groupAssetCalculators)
    }

    private func filterAssets(for query: String, chains: [ChainModel.Id: ChainModel]) -> [ChainAsset] {
        let chainAssets = chains.values.flatMap { chain in
            chain.assets.map { ChainAsset(chain: chain, asset: $0) }
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

        let allMatchedChains = chains.values.reduce(into: [ChainAsset]()) { result, chain in
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

        return allMatchedAssets + allMatchedChains
    }

    private func provideAssetsViewModel() {
        let maybePrices = try? priceResult?.get()
        let maybeCrowdloans = try? crowdloansResult?.get()

        let viewModels: [AssetListGroupViewModel] = groups.allItems.compactMap { groupModel in
            createGroupViewModel(from: groupModel, maybePrices: maybePrices, maybeCrowdloans: maybeCrowdloans)
        }

        if viewModels.isEmpty, !balanceResults.isEmpty, balanceResults.count >= allChains.count {
            view?.didReceiveGroups(state: .empty)
        } else {
            view?.didReceiveGroups(state: .list(groups: viewModels))
        }
    }

    private func createGroupViewModel(
        from groupModel: AssetListGroupModel,
        maybePrices: [ChainAssetId: PriceData]?,
        maybeCrowdloans _: [ChainModel.Id: [CrowdloanContributionData]]?
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

    override func didReceiveChainModelChanges(_ changes: [DataProviderChange<ChainModel>]) {
        storeChainChanges(changes)

        filterAndUpdateView()
    }

    override func didReceiveBalance(results: [ChainAssetId: Result<CalculatedAssetBalance?, Error>]) {
        super.didReceiveBalance(results: results)

        filterAndUpdateView()
    }

    override func didReceivePrices(result: Result<[ChainAssetId: PriceData], Error>?) {
        super.didReceivePrices(result: result)

        filterAndUpdateView()
    }

    override func didReceiveCrowdloans(result: Result<[ChainModel.Id: [CrowdloanContributionData]], Error>) {
        super.didReceiveCrowdloans(result: result)

        filterAndUpdateView()
    }
}

extension AssetsSearchPresenter: AssetsSearchPresenterProtocol {
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

extension AssetsSearchPresenter: AssetsSearchInteractorOutputProtocol {}

extension AssetsSearchPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideAssetsViewModel()
        }
    }
}
