import Foundation
import BigInt
import Operation_iOS
import SoraFoundation

typealias ChainAssetsFilter = (ChainAsset) -> Bool

class AssetsSearchPresenter: AssetsSearchPresenterProtocol {
    weak var view: AssetsSearchViewProtocol?
    weak var delegate: AssetsSearchDelegate?

    let wireframe: AssetsSearchWireframeProtocol
    let interactor: AssetsSearchInteractorInputProtocol
    let viewModelFactory: AssetListAssetViewModelFactoryProtocol

    private(set) var result: AssetSearchBuilderResult?

    init(
        delegate: AssetsSearchDelegate?,
        interactor: AssetsSearchInteractorInputProtocol,
        wireframe: AssetsSearchWireframeProtocol,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.delegate = delegate
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    private func provideAssetsViewModel() {
        guard let result = result else {
            return
        }

        let maybePrices = try? result.state.priceResult?.get()

        let viewModels: [AssetListGroupViewModel] = result.groups.allItems.compactMap { groupModel in
            createGroupViewModel(from: groupModel, groupLists: result.groupLists, maybePrices: maybePrices)
        }

        if viewModels.isEmpty {
            view?.didReceiveGroups(state: .empty)
        } else {
            view?.didReceiveGroups(state: .list(groups: viewModels))
        }
    }

    private func createGroupViewModel(
        from groupModel: AssetListChainGroupModel,
        groupLists: [ChainModel.Id: ListDifferenceCalculator<AssetListAssetModel>],
        maybePrices: [ChainAssetId: PriceData]?
    ) -> AssetListGroupViewModel? {
        let chain = groupModel.chain

        let assets = groupLists[chain.chainId]?.allItems ?? []

        let assetInfoList: [AssetListAssetAccountInfo] = assets.map { asset in
            AssetListPresenterHelpers.createAssetAccountInfo(
                from: asset,
                chain: chain,
                maybePrices: maybePrices
            )
        }

        return viewModelFactory.createGroupViewModel(
            for: chain,
            assets: assetInfoList,
            value: groupModel.value,
            connected: true,
            locale: selectedLocale
        )
    }

    // MARK: - AssetsSearchPresenterProtocol

    func setup() {
        interactor.setup()
    }

    func selectAsset(for chainAssetId: ChainAssetId) {
        delegate?.assetSearchDidSelect(chainAssetId: chainAssetId)

        wireframe.close(view: view)
    }

    func updateSearch(query: String) {
        interactor.search(query: query)
    }

    func cancel() {
        wireframe.close(view: view)
    }
}

extension AssetsSearchPresenter: AssetsSearchInteractorOutputProtocol {
    func didReceive(result: AssetSearchBuilderResult) {
        self.result = result

        provideAssetsViewModel()
    }
}

extension AssetsSearchPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideAssetsViewModel()
        }
    }
}
