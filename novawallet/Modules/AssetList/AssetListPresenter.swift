import Foundation
import RobinHood
import SubstrateSdk
import SoraFoundation
import BigInt
import CommonWallet

final class AssetListPresenter: AssetListBasePresenter {
    static let viewUpdatePeriod: TimeInterval = 1.0

    weak var view: AssetListViewProtocol?
    let wireframe: AssetListWireframeProtocol
    let interactor: AssetListInteractorInputProtocol
    let viewModelFactory: AssetListViewModelFactoryProtocol

    private(set) var nftList: ListDifferenceCalculator<NftModel>

    private var genericAccountId: AccountId?
    private var walletType: MetaAccountModelType?
    private var name: String?
    private var hidesZeroBalances: Bool?
    private(set) var connectionStates: [ChainModel.Id: WebSocketEngine.State] = [:]

    private var scheduler: SchedulerProtocol?

    deinit {
        cancelViewUpdate()
    }

    init(
        interactor: AssetListInteractorInputProtocol,
        wireframe: AssetListWireframeProtocol,
        viewModelFactory: AssetListViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        nftList = Self.createNftDiffCalculator()

        super.init()

        self.localizationManager = localizationManager
    }

    private func provideHeaderViewModel() {
        guard let genericAccountId = genericAccountId, let walletType = walletType, let name = name else {
            return
        }

        guard case let .success(priceMapping) = priceResult, !balanceResults.isEmpty else {
            let viewModel = viewModelFactory.createHeaderViewModel(
                from: name,
                accountId: genericAccountId,
                walletType: walletType,
                prices: nil,
                locale: selectedLocale
            )

            view?.didReceiveHeader(viewModel: viewModel)
            return
        }

        provideHeaderViewModel(
            with: priceMapping,
            genericAccountId: genericAccountId,
            walletType: walletType,
            name: name
        )
    }

    private func provideHeaderViewModel(
        with priceMapping: [ChainAssetId: PriceData],
        genericAccountId: AccountId,
        walletType: MetaAccountModelType,
        name: String
    ) {
        let priceState: LoadableViewModelState<[AssetListAssetAccountPrice]> = priceMapping.reduce(
            LoadableViewModelState.loaded(value: [])
        ) { result, keyValue in
            let chainAssetId = keyValue.key
            let chainId = chainAssetId.chainId
            let assetId = chainAssetId.assetId
            switch result {
            case .loading:
                return .loading
            case let .cached(items):
                guard
                    let chain = allChains[chainId],
                    let asset = chain.assets.first(where: { $0.assetId == assetId }) else {
                    return .cached(value: items)
                }

                let totalBalance: BigUInt

                if case let .success(assetBalance) = balanceResults[chainAssetId] {
                    totalBalance = assetBalance
                } else {
                    totalBalance = 0
                }

                let newItem = AssetListAssetAccountPrice(
                    assetInfo: asset.displayInfo,
                    balance: totalBalance,
                    price: keyValue.value
                )

                return .cached(value: items + [newItem])
            case let .loaded(items):
                guard
                    let chain = allChains[chainId],
                    let asset = chain.assets.first(where: { $0.assetId == assetId }) else {
                    return .cached(value: items)
                }

                if case let .success(assetBalance) = balanceResults[chainAssetId] {
                    let newItem = AssetListAssetAccountPrice(
                        assetInfo: asset.displayInfo,
                        balance: assetBalance,
                        price: keyValue.value
                    )

                    return .loaded(value: items + [newItem])
                } else {
                    let newItem = AssetListAssetAccountPrice(
                        assetInfo: asset.displayInfo,
                        balance: 0,
                        price: keyValue.value
                    )

                    return .cached(value: items + [newItem])
                }
            }
        }

        let viewModel = viewModelFactory.createHeaderViewModel(
            from: name,
            accountId: genericAccountId,
            walletType: walletType,
            prices: priceState,
            locale: selectedLocale
        )

        view?.didReceiveHeader(viewModel: viewModel)
    }

    private func calculateNftBalance(for chainAsset: ChainAsset) -> BigUInt {
        guard chainAsset.asset.isUtility else {
            return 0
        }

        return nftList.allItems.compactMap { nft in
            guard nft.chainId == chainAsset.chain.chainId, let price = nft.price else {
                return nil
            }

            return BigUInt(price)
        }.reduce(BigUInt(0)) { total, value in
            total + value
        }
    }

    private func provideAssetViewModels() {
        guard let hidesZeroBalances = hidesZeroBalances else {
            return
        }

        let maybePrices = try? priceResult?.get()
        let viewModels: [AssetListGroupViewModel] = groups.allItems.compactMap { groupModel in
            createGroupViewModel(
                from: groupModel,
                maybePrices: maybePrices,
                hidesZeroBalances: hidesZeroBalances
            )
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
        hidesZeroBalances: Bool
    ) -> AssetListGroupViewModel? {
        let chain = groupModel.chain

        let assets = groupLists[chain.chainId]?.allItems ?? []

        let filteredAssets: [AssetListAssetModel]

        if hidesZeroBalances {
            filteredAssets = assets.filter { asset in
                if let balance = try? asset.balanceResult?.get(), balance > 0 {
                    return true
                } else {
                    return false
                }
            }

            guard !filteredAssets.isEmpty else {
                return nil
            }
        } else {
            filteredAssets = assets
        }

        let connected: Bool

        if let chainState = connectionStates[chain.chainId], case .connected = chainState {
            connected = true
        } else {
            connected = false
        }

        let assetInfoList: [AssetListAssetAccountInfo] = filteredAssets.map { asset in
            createAssetAccountInfo(from: asset, chain: chain, maybePrices: maybePrices)
        }

        return viewModelFactory.createGroupViewModel(
            for: chain,
            assets: assetInfoList,
            value: groupModel.chainValue,
            connected: connected,
            locale: selectedLocale
        )
    }

    private func provideNftViewModel() {
        let allNfts = nftList.allItems

        guard !allNfts.isEmpty else {
            view?.didReceiveNft(viewModel: nil)
            return
        }

        let nftViewModel = viewModelFactory.createNftsViewModel(from: allNfts, locale: selectedLocale)
        view?.didReceiveNft(viewModel: nftViewModel)
    }

    private func updateAssetsView() {
        cancelViewUpdate()

        provideHeaderViewModel()
        provideAssetViewModels()
    }

    private func updateHeaderView() {
        provideHeaderViewModel()
    }

    private func updateNftView() {
        provideNftViewModel()
    }

    private func scheduleViewUpdate() {
        guard scheduler == nil else {
            return
        }

        scheduler = Scheduler(with: self, callbackQueue: .main)
        scheduler?.notifyAfter(Self.viewUpdatePeriod)
    }

    private func cancelViewUpdate() {
        scheduler?.cancel()
        scheduler = nil
    }

    private func presentAssetDetails(for chainAssetId: ChainAssetId) {
        guard
            let chain = allChains[chainAssetId.chainId],
            let asset = chain.assets.first(where: { $0.assetId == chainAssetId.assetId }) else {
            return
        }

        wireframe.showAssetDetails(from: view, chain: chain, asset: asset)
    }

    // MARK: Interactor Output overridings

    override func didReceivePrices(result: Result<[ChainAssetId: PriceData], Error>?) {
        view?.didCompleteRefreshing()

        super.didReceivePrices(result: result)

        updateAssetsView()
    }

    override func didReceiveChainModelChanges(_ changes: [DataProviderChange<ChainModel>]) {
        super.didReceiveChainModelChanges(changes)

        updateAssetsView()
    }

    override func didReceiveBalance(results: [ChainAssetId: Result<BigUInt?, Error>]) {
        super.didReceiveBalance(results: results)

        updateAssetsView()
    }
}

extension AssetListPresenter: AssetListPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func selectWallet() {
        wireframe.showWalletSwitch(from: view)
    }

    func selectAsset(for chainAssetId: ChainAssetId) {
        presentAssetDetails(for: chainAssetId)
    }

    func selectNfts() {
        wireframe.showNfts(from: view)
    }

    func refresh() {
        interactor.refresh()
    }

    func presentSettings() {
        wireframe.showAssetsManage(from: view)
    }

    func presentSearch() {
        let initState = AssetListInitState(
            priceResult: priceResult,
            balanceResults: balanceResults,
            allChains: allChains
        )

        wireframe.showAssetsSearch(from: view, initState: initState, delegate: self)
    }
}

extension AssetListPresenter: AssetListInteractorOutputProtocol {
    func didReceiveNft(changes: [DataProviderChange<NftModel>]) {
        nftList.apply(changes: changes)

        updateNftView()
    }

    func didReceiveNft(error _: Error) {}

    func didResetNftProvider() {
        nftList = Self.createNftDiffCalculator()
    }

    func didReceive(genericAccountId: AccountId, walletType: MetaAccountModelType, name: String) {
        self.genericAccountId = genericAccountId
        self.walletType = walletType
        self.name = name

        resetStorages()

        nftList = Self.createNftDiffCalculator()

        updateAssetsView()
        updateNftView()
    }

    func didReceive(state: WebSocketEngine.State, for chainId: ChainModel.Id) {
        connectionStates[chainId] = state

        scheduleViewUpdate()
    }

    func didChange(name: String) {
        self.name = name

        updateHeaderView()
    }

    func didReceive(hidesZeroBalances: Bool) {
        self.hidesZeroBalances = hidesZeroBalances

        updateAssetsView()
    }
}

extension AssetListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateAssetsView()
            updateNftView()
        }
    }
}

extension AssetListPresenter: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        updateAssetsView()
    }
}

extension AssetListPresenter: AssetsSearchDelegate {
    func assetSearchDidSelect(chainAssetId: ChainAssetId) {
        presentAssetDetails(for: chainAssetId)
    }
}
