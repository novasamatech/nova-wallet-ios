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

    private var walletIdenticon: Data?
    private var walletType: MetaAccountModelType?
    private var name: String?
    private var hidesZeroBalances: Bool?

    private(set) var connectionStates: [ChainModel.Id: WebSocketEngine.State] = [:]
    private(set) var locksResult: Result<[AssetLock], Error>?
    private(set) var walletConnectSessionsCount: Int = 0

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
        guard let walletType = walletType, let name = name else {
            return
        }

        guard case let .success(priceMapping) = priceResult, !balanceResults.isEmpty else {
            let viewModel = viewModelFactory.createHeaderViewModel(
                from: name,
                walletIdenticon: walletIdenticon,
                walletType: walletType,
                prices: nil,
                locks: nil,
                walletConnectSessionsCount: walletConnectSessionsCount,
                locale: selectedLocale
            )

            view?.didReceiveHeader(viewModel: viewModel)
            return
        }

        provideHeaderViewModel(
            with: priceMapping,
            walletIdenticon: walletIdenticon,
            walletType: walletType,
            name: name
        )
    }

    typealias SuccessAssetListAssetAccountPrice = AssetListAssetAccountPrice
    typealias FailedAssetListAssetAccountPrice = AssetListAssetAccountPrice
    private func createAssetAccountPrice(
        chainAssetId: ChainAssetId,
        priceData: PriceData
    ) -> Either<SuccessAssetListAssetAccountPrice, FailedAssetListAssetAccountPrice>? {
        let chainId = chainAssetId.chainId
        let assetId = chainAssetId.assetId

        guard let chain = allChains[chainId],
              let asset = chain.assets.first(where: { $0.assetId == assetId }) else {
            return nil
        }

        guard case let .success(assetBalance) = balances[chainAssetId] else {
            return .right(
                AssetListAssetAccountPrice(
                    assetInfo: asset.displayInfo,
                    balance: 0,
                    price: priceData
                )
            )
        }

        return .left(
            AssetListAssetAccountPrice(
                assetInfo: asset.displayInfo,
                balance: assetBalance.totalInPlank,
                price: priceData
            ))
    }

    private func createAssetAccountPriceLock(
        chainAssetId: ChainAssetId,
        priceData: PriceData
    ) -> AssetListAssetAccountPrice? {
        let chainId = chainAssetId.chainId
        let assetId = chainAssetId.assetId

        guard let chain = allChains[chainId],
              let asset = chain.assets.first(where: { $0.assetId == assetId }) else {
            return nil
        }

        guard case let .success(assetBalance) = balances[chainAssetId], assetBalance.locked > 0 else {
            return nil
        }

        return AssetListAssetAccountPrice(
            assetInfo: asset.displayInfo,
            balance: assetBalance.locked,
            price: priceData
        )
    }

    private func provideHeaderViewModel(
        with priceMapping: [ChainAssetId: PriceData],
        walletIdenticon: Data?,
        walletType: MetaAccountModelType,
        name: String
    ) {
        let crowdloans = crowdloansModel(prices: priceMapping)
        let totalValue = createHeaderPriceState(from: priceMapping, crowdloans: crowdloans)
        let totalLocks = createHeaderLockState(from: priceMapping, crowdloans: crowdloans)

        let viewModel = viewModelFactory.createHeaderViewModel(
            from: name,
            walletIdenticon: walletIdenticon,
            walletType: walletType,
            prices: totalValue,
            locks: totalLocks,
            walletConnectSessionsCount: walletConnectSessionsCount,
            locale: selectedLocale
        )

        view?.didReceiveHeader(viewModel: viewModel)
    }

    private func createHeaderPriceState(
        from priceMapping: [ChainAssetId: PriceData],
        crowdloans: [AssetListAssetAccountPrice]
    ) -> LoadableViewModelState<[AssetListAssetAccountPrice]> {
        var priceState: LoadableViewModelState<[AssetListAssetAccountPrice]> = .loaded(value: [])

        for (chainAssetId, priceData) in priceMapping {
            switch priceState {
            case .loading:
                priceState = .loading
            case let .cached(items):
                guard let newItem = createAssetAccountPrice(
                    chainAssetId: chainAssetId,
                    priceData: priceData
                ) else {
                    priceState = .cached(value: items)
                    continue
                }
                priceState = .cached(value: items + [newItem.value])
            case let .loaded(items):
                guard let newItem = createAssetAccountPrice(
                    chainAssetId: chainAssetId,
                    priceData: priceData
                ) else {
                    priceState = .cached(value: items)
                    continue
                }

                switch newItem {
                case let .left(item):
                    priceState = .loaded(value: items + [item])
                case let .right(item):
                    priceState = .cached(value: items + [item])
                }
            }
        }

        return priceState + crowdloans
    }

    private func createHeaderLockState(
        from priceMapping: [ChainAssetId: PriceData],
        crowdloans: [AssetListAssetAccountPrice]
    ) -> [AssetListAssetAccountPrice]? {
        guard checkNonZeroLocks() else {
            return nil
        }

        let locks: [AssetListAssetAccountPrice] = priceMapping.reduce(into: []) { accum, keyValue in
            if let lock = createAssetAccountPriceLock(chainAssetId: keyValue.key, priceData: keyValue.value) {
                accum.append(lock)
            }
        }

        return locks + crowdloans
    }

    private func checkNonZeroLocks() -> Bool {
        let locks = balances.map { (try? $0.value.get())?.locked ?? 0 }

        if locks.contains(where: { $0 > 0 }) {
            return true
        }

        let crowdloanContributions = (try? crowdloansResult?.get()) ?? [:]

        if crowdloanContributions.contains(where: { $0.value.contains(where: { $0.amount > 0 }) }) {
            return true
        }

        return false
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
        let maybeCrowdloans = try? crowdloansResult?.get()
        let viewModels: [AssetListGroupViewModel] = groups.allItems.compactMap { groupModel in
            createGroupViewModel(
                from: groupModel,
                maybePrices: maybePrices,
                maybeCrowdloans: maybeCrowdloans,
                hidesZeroBalances: hidesZeroBalances
            )
        }

        if viewModels.isEmpty, !balanceResults.isEmpty, balanceResults.count >= allChains.count {
            view?.didReceiveGroups(state: .empty)
        } else {
            view?.didReceiveGroups(state: .list(groups: viewModels))
        }
    }

    private func crowdloansModel(prices: [ChainAssetId: PriceData]) -> [AssetListAssetAccountPrice] {
        switch crowdloansResult {
        case .failure, .none:
            return []
        case let .success(crowdloans):
            return crowdloans.compactMap { chainId, chainCrowdloans in
                guard let chain = allChains[chainId] else {
                    return nil
                }
                guard let asset = chain.utilityAsset() else {
                    return nil
                }
                let chainAssetId = ChainAssetId(chainId: chainId, assetId: asset.assetId)
                let price = prices[chainAssetId] ?? .zero()

                let contributedAmount = chainCrowdloans.reduce(0) { $0 + $1.amount }

                guard contributedAmount > 0 else {
                    return nil
                }

                return AssetListAssetAccountPrice(
                    assetInfo: asset.displayInfo,
                    balance: contributedAmount,
                    price: price
                )
            }
        }
    }

    private func createGroupViewModel(
        from groupModel: AssetListGroupModel,
        maybePrices: [ChainAssetId: PriceData]?,
        maybeCrowdloans _: [ChainModel.Id: [CrowdloanContributionData]]?,
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
        // get chain from interactor that includes also disabled assets
        let optChain = interactor.getFullChain(for: chainAssetId.chainId) ?? allChains[chainAssetId.chainId]

        guard
            let chain = optChain,
            let asset = chain.assets.first(where: { $0.assetId == chainAssetId.assetId }) else {
            return
        }

        wireframe.showAssetDetails(from: view, chain: chain, asset: asset)
    }

    override func resetStorages() {
        super.resetStorages()
        locksResult = nil
    }

    // MARK: Interactor Output overridings

    override func didReceivePrice(changes: [ChainAssetId: DataProviderChange<PriceData>]) {
        view?.didCompleteRefreshing()

        super.didReceivePrice(changes: changes)

        updateAssetsView()
    }

    override func didReceivePrice(error: Error) {
        view?.didCompleteRefreshing()

        super.didReceivePrice(error: error)

        updateAssetsView()
    }

    override func didReceiveChainModelChanges(_ changes: [DataProviderChange<ChainModel>]) {
        super.didReceiveChainModelChanges(changes)

        updateAssetsView()
    }

    override func didReceiveBalance(results: [ChainAssetId: Result<CalculatedAssetBalance?, Error>]) {
        super.didReceiveBalance(results: results)

        updateAssetsView()
    }

    override func didReceiveCrowdloans(result: Result<[ChainModel.Id: [CrowdloanContributionData]], Error>) {
        super.didReceiveCrowdloans(result: result)

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
        wireframe.showAssetsSettings(from: view)
    }

    func presentSearch() {
        let initState = AssetListInitState(
            priceResult: priceResult,
            balanceResults: balanceResults,
            allChains: allChains,
            crowdloansResult: crowdloansResult
        )

        wireframe.showAssetsSearch(from: view, initState: initState, delegate: self)
    }

    func presentAssetsManage() {
        wireframe.showTokensManage(from: view)
    }

    func presentLocks() {
        guard
            checkNonZeroLocks(),
            let priceResult = priceResult,
            let prices = try? priceResult.get(),
            let locks = try? locksResult?.get(),
            let crowdloans = try? crowdloansResult?.get() else {
            return
        }

        wireframe.showBalanceBreakdown(
            from: view,
            prices: prices,
            balances: balances.values.compactMap { try? $0.get() },
            chains: allChains,
            locks: locks,
            crowdloans: crowdloans
        )
    }

    func send() {
        let initState = AssetListInitState(
            priceResult: priceResult,
            balanceResults: balanceResults,
            allChains: allChains,
            crowdloansResult: crowdloansResult
        )

        wireframe.showSendTokens(
            from: view,
            state: initState
        )
    }

    func receive() {
        let initState = AssetListInitState(
            priceResult: priceResult,
            balanceResults: balanceResults,
            allChains: allChains,
            crowdloansResult: crowdloansResult
        )

        wireframe.showRecieveTokens(
            from: view,
            state: initState
        )
    }

    func buy() {
        let initState = AssetListInitState(
            priceResult: priceResult,
            balanceResults: balanceResults,
            allChains: allChains,
            crowdloansResult: crowdloansResult
        )
        wireframe.showBuyTokens(
            from: view,
            state: initState
        )
    }

    func presentWalletConnect() {
        if walletConnectSessionsCount > 0 {
            wireframe.showWalletConnect(from: view)
        } else {
            wireframe.showScan(from: view, delegate: self)
        }
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

    func didReceive(walletIdenticon: Data?, walletType: MetaAccountModelType, name: String) {
        self.walletIdenticon = walletIdenticon
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

    func didReceiveLocks(result: Result<[AssetLock], Error>) {
        locksResult = result

        updateHeaderView()
    }

    func didReceiveWalletConnect(error: WalletConnectSessionsError) {
        switch error {
        case let .connectionFailed:
            wireframe.presentWCConnectionError(from: view, locale: selectedLocale)
        case let .sessionsFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryFetchWalletConnectSessionsCount()
            }
        }
    }

    func didReceiveWalletConnect(sessionsCount: Int) {
        walletConnectSessionsCount = sessionsCount
        updateHeaderView()
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

extension AssetListPresenter: URIScanDelegate {
    func uriScanDidReceive(uri: String, context _: AnyObject?) {
        wireframe.hideUriScanAnimated(from: view) { [weak self] in
            self?.interactor.connectWalletConnect(uri: uri)
        }
    }
}
