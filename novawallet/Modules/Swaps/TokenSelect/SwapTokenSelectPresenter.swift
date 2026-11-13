import Foundation
import Foundation_iOS

final class SwapTokenSelectPresenter {
    weak var view: SwapTokenSelectViewProtocol?
    let wireframe: SwapTokenSelectWireframeProtocol
    let interactor: SwapTokenSelectInteractorInputProtocol
    let viewModelFactory: SwapTokenSelectViewModelFactoryProtocol
    let side: SwapTokenSelectionSide
    let context: SwapTokenSelectionContext
    let completion: (SwapTokenSelectionResult) -> Void
    let logger: LoggerProtocol

    private var assetList: AssetListModel?
    private var routeUniverse: Set<ChainAssetId>?
    private var swappable: Set<ChainAssetId>?
    private var savedNetworks: [ChainModel.Id] = []
    private var selectedNetworks: Set<ChainModel.Id> = []
    private var query: String = ""
    private var list: SwapTokenSelectList?
    private var pendingSelection: ChainAsset?

    init(
        interactor: SwapTokenSelectInteractorInputProtocol,
        wireframe: SwapTokenSelectWireframeProtocol,
        viewModelFactory: SwapTokenSelectViewModelFactoryProtocol,
        side: SwapTokenSelectionSide,
        context: SwapTokenSelectionContext,
        completion: @escaping (SwapTokenSelectionResult) -> Void,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.side = side
        self.context = context
        self.completion = completion
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

// MARK: Private

private extension SwapTokenSelectPresenter {
    func provideTitle() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        let title = switch side {
        case .pay:
            strings.swapsSetupAssetActionSelectPay()
        case .receive:
            strings.swapsSetupAssetActionSelectReceive()
        }

        view?.didReceive(title: title)
    }

    func rebuildList() {
        list = assetList.flatMap { assetList in
            SwapTokenSelectListBuilder.build(
                from: SwapTokenSelectListParams(
                    side: side,
                    context: context,
                    assetList: assetList,
                    routeUniverse: routeUniverse,
                    swappable: swappable,
                    query: query,
                    networkFilter: selectedNetworks
                )
            )
        }

        provideList()
        provideChips()
    }

    func provideList() {
        let params = SwapTokenSelectListViewModelParams(
            currentChainAssetId: context.current?.chainAssetId,
            counterpartSymbol: context.counterpart?.asset.symbol
        )

        let viewModel = viewModelFactory.createListViewModel(
            from: list,
            params: params,
            locale: selectedLocale
        )

        view?.didReceive(list: viewModel)
    }

    func provideChips() {
        let chipRow = SwapTokenSelectNetworksArranger.chipRow(
            from: list?.networks ?? [],
            savedNetworks: savedNetworks
        )

        let viewModels = viewModelFactory.createChipViewModels(
            from: chipRow,
            selectedNetworks: selectedNetworks,
            locale: selectedLocale
        )

        view?.didReceive(chips: viewModels)
    }

    func showNetworkSelection() {
        guard let networks = list?.networks else {
            return
        }

        let viewModels = viewModelFactory.createNetworkViewModels(
            from: SwapTokenSelectNetworksArranger.sheetOrder(of: networks),
            selectedNetworks: Set(savedNetworks)
        )

        wireframe.showNetworkSelection(from: view, viewModels: viewModels) { [weak self] chainIds in
            self?.selectedNetworks = Set(chainIds)
            self?.interactor.save(networks: chainIds)
            self?.view?.didResetChipsScroll()
        }
    }

    func findChainAsset(for chainAssetId: ChainAssetId) -> ChainAsset? {
        guard let list else {
            return nil
        }

        let items = list.yourTokens + list.otherTokens + list.notSwappable

        return items.first { $0.chainAsset.chainAssetId == chainAssetId }?.chainAsset
    }

    func completeSelectionIfPossible(of chainAsset: ChainAsset) {
        guard context.counterpart != nil else {
            complete(with: .selected(chainAsset))
            return
        }

        guard let swappable else {
            pendingSelection = chainAsset
            return
        }

        if swappable.contains(chainAsset.chainAssetId) {
            complete(with: .selected(chainAsset))
        } else {
            complete(with: .selectedClearingCounterpart(chainAsset))
        }
    }

    func complete(with result: SwapTokenSelectionResult) {
        pendingSelection = nil
        completion(result)
        wireframe.close(view: view)
    }
}

// MARK: SwapTokenSelectPresenterProtocol

extension SwapTokenSelectPresenter: SwapTokenSelectPresenterProtocol {
    func setup() {
        provideTitle()
        provideList()
        provideChips()

        interactor.setup()
    }

    func search(query: String) {
        self.query = query
        rebuildList()
    }

    func selectChip(_ kind: SwapTokenSelectChipViewModel.Kind) {
        switch kind {
        case .all:
            selectedNetworks = []
        case let .network(chainId):
            selectedNetworks = [chainId]
        case .more:
            showNetworkSelection()
            return
        }

        rebuildList()
    }

    func selectToken(with chainAssetId: ChainAssetId) {
        guard pendingSelection == nil, let chainAsset = findChainAsset(for: chainAssetId) else {
            return
        }

        if chainAssetId == context.current?.chainAssetId {
            wireframe.close(view: view)
        } else {
            completeSelectionIfPossible(of: chainAsset)
        }
    }

    func close() {
        wireframe.close(view: view)
    }
}

// MARK: SwapTokenSelectInteractorOutputProtocol

extension SwapTokenSelectPresenter: SwapTokenSelectInteractorOutputProtocol {
    func didReceive(assetList: AssetListModel) {
        self.assetList = assetList
        rebuildList()
    }

    func didReceive(routeUniverse: Set<ChainAssetId>) {
        self.routeUniverse = routeUniverse
        rebuildList()
    }

    func didReceive(swappable: Set<ChainAssetId>) {
        self.swappable = swappable
        rebuildList()

        if let pendingSelection {
            completeSelectionIfPossible(of: pendingSelection)
        }
    }

    func didReceive(savedNetworks: [ChainModel.Id]) {
        self.savedNetworks = savedNetworks
        rebuildList()
    }

    func didReceive(error: SwapTokenSelectError) {
        logger.error("Token select error: \(error)")

        wireframe.presentRequestStatus(
            on: view,
            locale: selectedLocale,
            retryAction: { [weak self] in
                self?.interactor.refreshRoutes()
            }
        )
    }
}

// MARK: Localizable

extension SwapTokenSelectPresenter: Localizable {
    func applyLocalization() {
        guard view?.isSetup == true else {
            return
        }

        provideTitle()
        provideList()
        provideChips()
    }
}
