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

    private(set) var assetListStyle: AssetListGroupsStyle?

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
        guard
            let result,
            let assetListStyle
        else {
            return
        }

        let maybePrices = try? result.state.priceResult?.get()

        let viewModels: [AssetListGroupType] = switch assetListStyle {
        case .networks:
            result.chainGroups.compactMap {
                createChainGroupViewModel(
                    from: $0,
                    maybePrices: maybePrices
                )
            }
        case .tokens:
            result.assetGroups.compactMap {
                createAssetGroupViewModel(
                    from: $0,
                    maybePrices: maybePrices
                )
            }
        }

        let state: AssetListGroupState = viewModels.isEmpty ? .empty : .list(groups: viewModels)

        let groupViewModel = AssetListViewModel(
            isFiltered: false,
            listState: state,
            listGroupStyle: assetListStyle
        )

        view?.didReceiveList(viewModel: groupViewModel)
    }

    private func createAssetGroupViewModel(
        from groupModel: AssetListAssetGroupModel,
        maybePrices: [ChainAssetId: PriceData]?
    ) -> AssetListGroupType? {
        guard let result else {
            return nil
        }

        let assets = result.groupListsByAsset[groupModel.multichainToken.symbol] ?? []

        guard !assets.isEmpty else {
            return nil
        }

        return if let groupViewModel = viewModelFactory.createTokenGroupViewModel(
            assetsList: assets,
            group: groupModel,
            maybePrices: maybePrices,
            connected: true,
            locale: selectedLocale
        ) {
            .token(groupViewModel)
        } else {
            nil
        }
    }

    private func createChainGroupViewModel(
        from groupModel: AssetListChainGroupModel,
        maybePrices: [ChainAssetId: PriceData]?
    ) -> AssetListGroupType? {
        guard let result else {
            return nil
        }

        let chain = groupModel.chain

        let assets = result.groupListsByChain[chain.chainId] ?? []

        let assetInfoList: [AssetListAssetAccountInfo] = assets.map { asset in
            AssetListPresenterHelpers.createAssetAccountInfo(
                from: asset,
                chain: chain,
                maybePrices: maybePrices
            )
        }

        let groupViewModel = viewModelFactory.createNetworkGroupViewModel(
            for: chain,
            assets: assetInfoList,
            value: groupModel.value,
            connected: true,
            locale: selectedLocale
        )

        return .network(groupViewModel)
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

    func didReceiveAssetGroupsStyle(_ style: AssetListGroupsStyle) {
        assetListStyle = style

        view?.didReceiveAssetGroupsStyle(style)
    }
}

extension AssetsSearchPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideAssetsViewModel()
        }
    }
}
