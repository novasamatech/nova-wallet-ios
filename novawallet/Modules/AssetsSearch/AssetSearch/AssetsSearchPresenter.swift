import Foundation
import BigInt
import Operation_iOS
import Foundation_iOS

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

    func selectGroup(with symbol: AssetModel.Symbol) {
        processGroupSelectionWithCheck(
            symbol,
            onSingleInstance: { chainAsset in
                processAssetSelected(with: chainAsset.chainAssetId)
            },
            onMultipleInstances: { _ in }
        )
    }

    func processGroupSelectionWithCheck(
        _ symbol: String,
        onSingleInstance: (ChainAsset) -> Void,
        onMultipleInstances: (MultichainToken) -> Void
    ) {
        guard let multichainToken = result?.assetGroups.first(
            where: { $0.multichainToken.symbol == symbol }
        )?.multichainToken else {
            return
        }

        if multichainToken.instances.count > 1 {
            onMultipleInstances(multichainToken)
        } else if
            let chainAssetId = multichainToken.instances.first?.chainAssetId,
            let chainAsset = result?.state.chainAsset(for: chainAssetId) {
            onSingleInstance(chainAsset)
        }
    }

    // MARK: - AssetsSearchPresenterProtocol

    func setup() {
        interactor.setup()
    }

    func selectAsset(for chainAssetId: ChainAssetId) {
        processAssetSelected(with: chainAssetId)
    }

    func updateSearch(query: String) {
        interactor.search(query: query)
    }

    func cancel() {
        wireframe.close(view: view)
    }
}

// MARK: - Private

private extension AssetsSearchPresenter {
    func processAssetSelected(with chainAssetId: ChainAssetId) {
        delegate?.assetSearchDidSelect(chainAssetId: chainAssetId)

        wireframe.close(view: view)
    }

    func provideAssetsViewModel() {
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

    func createAssetGroupViewModel(
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

        let params = AssetListTokenGroupViewModelParams(
            assetsList: assets,
            group: groupModel,
            maybePrices: maybePrices,
            connected: true
        )

        return if let groupViewModel = viewModelFactory.createTokenGroupViewModel(
            params: params,
            genericParams: createGenericViewModelFactoryParams()
        ) {
            .token(groupViewModel)
        } else {
            nil
        }
    }

    func createChainGroupViewModel(
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

        let params = AssetListNetworkGroupViewModelParams(
            chain: chain,
            assets: assetInfoList,
            value: groupModel.value,
            connected: true
        )

        let groupViewModel = viewModelFactory.createNetworkGroupViewModel(
            params: params,
            genericParams: createGenericViewModelFactoryParams()
        )

        return .network(groupViewModel)
    }

    func createGenericViewModelFactoryParams() -> ViewModelFactoryGenericParams {
        ViewModelFactoryGenericParams(locale: selectedLocale)
    }
}

// MARK: - AssetsSearchInteractorOutputProtocol

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

// MARK: - Localizable

extension AssetsSearchPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideAssetsViewModel()
        }
    }
}
