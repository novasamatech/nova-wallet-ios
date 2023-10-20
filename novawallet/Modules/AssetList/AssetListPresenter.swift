import Foundation
import RobinHood
import SubstrateSdk
import SoraFoundation
import BigInt

final class AssetListPresenter {
    typealias SuccessAssetListAssetAccountPrice = AssetListAssetAccountPrice
    typealias FailedAssetListAssetAccountPrice = AssetListAssetAccountPrice

    static let viewUpdatePeriod: TimeInterval = 1.0

    weak var view: AssetListViewProtocol?
    let wireframe: AssetListWireframeProtocol
    let interactor: AssetListInteractorInputProtocol
    let viewModelFactory: AssetListViewModelFactoryProtocol

    private(set) var walletId: MetaAccountModel.Id?
    private var walletIdenticon: Data?
    private var walletType: MetaAccountModelType?
    private var name: String?
    private var hidesZeroBalances: Bool?
    private var shouldShowPolkadotPromotion: Bool = true

    private(set) var walletConnectSessionsCount: Int = 0

    private(set) var model: AssetListBuilderResult.Model = .init()

    init(
        interactor: AssetListInteractorInputProtocol,
        wireframe: AssetListWireframeProtocol,
        viewModelFactory: AssetListViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    private func providePolkadotStakingPromotion() {
        guard shouldShowPolkadotPromotion else {
            return
        }

        let viewModel = PromotionViewModelFactory.createPolkadotStakingPromotion(for: selectedLocale)

        view?.didReceivePromotion(viewModel: viewModel)
    }

    private func provideHeaderViewModel() {
        guard let walletType = walletType, let name = name else {
            return
        }

        guard case let .success(priceMapping) = model.priceResult, !model.balanceResults.isEmpty else {
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

    private func createAssetAccountPrice(
        chainAssetId: ChainAssetId,
        priceData: PriceData
    ) -> Either<SuccessAssetListAssetAccountPrice, FailedAssetListAssetAccountPrice>? {
        let chainId = chainAssetId.chainId
        let assetId = chainAssetId.assetId

        guard let chain = model.allChains[chainId],
              let asset = chain.assets.first(where: { $0.assetId == assetId }) else {
            return nil
        }

        guard case let .success(assetBalance) = model.balances[chainAssetId] else {
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

        guard let chain = model.allChains[chainId],
              let asset = chain.assets.first(where: { $0.assetId == assetId }) else {
            return nil
        }

        guard case let .success(assetBalance) = model.balances[chainAssetId], assetBalance.locked > 0 else {
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
        let externalBalances = externalBalanceModel(prices: priceMapping)
        let totalValue = createHeaderPriceState(from: priceMapping, externalBalances: externalBalances)
        let totalLocks = createHeaderLockState(from: priceMapping, externalBalances: externalBalances)

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
        externalBalances: [AssetListAssetAccountPrice]
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

        return priceState + externalBalances
    }

    private func createHeaderLockState(
        from priceMapping: [ChainAssetId: PriceData],
        externalBalances: [AssetListAssetAccountPrice]
    ) -> [AssetListAssetAccountPrice]? {
        guard checkNonZeroLocks() else {
            return nil
        }

        let locks: [AssetListAssetAccountPrice] = priceMapping.reduce(into: []) { accum, keyValue in
            if let lock = createAssetAccountPriceLock(chainAssetId: keyValue.key, priceData: keyValue.value) {
                accum.append(lock)
            }
        }

        return locks + externalBalances
    }

    private func checkNonZeroLocks() -> Bool {
        let locks = model.balances.map { (try? $0.value.get())?.locked ?? 0 }

        if locks.contains(where: { $0 > 0 }) {
            return true
        }

        let externalBalances = (try? model.externalBalanceResult?.get()) ?? [:]

        if externalBalances.contains(where: { $0.value.contains(where: { $0.amount > 0 }) }) {
            return true
        }

        return false
    }

    private func provideAssetViewModels() {
        guard let hidesZeroBalances = hidesZeroBalances else {
            return
        }

        let maybePrices = try? model.priceResult?.get()
        let viewModels: [AssetListGroupViewModel] = model.groups.compactMap { groupModel in
            createGroupViewModel(
                from: groupModel,
                maybePrices: maybePrices,
                hidesZeroBalances: hidesZeroBalances
            )
        }

        let isFilterOn = hidesZeroBalances == true
        if viewModels.isEmpty, !model.balanceResults.isEmpty, model.balanceResults.count >= model.allChains.count {
            view?.didReceiveGroups(viewModel: .init(
                isFiltered: isFilterOn,
                listState: .empty
            ))
        } else {
            view?.didReceiveGroups(viewModel: .init(
                isFiltered: isFilterOn,
                listState: .list(groups: viewModels)
            ))
        }
    }

    private func externalBalanceModel(prices: [ChainAssetId: PriceData]) -> [AssetListAssetAccountPrice] {
        switch model.externalBalanceResult {
        case .failure, .none:
            return []
        case let .success(externalBalance):
            return externalBalance.compactMap { chainAssetId, externalAssetBalances in
                guard let chain = model.allChains[chainAssetId.chainId] else {
                    return nil
                }
                guard let asset = chain.asset(for: chainAssetId.assetId) else {
                    return nil
                }

                let price = prices[chainAssetId] ?? .zero()

                let contributedAmount = externalAssetBalances.reduce(0) { $0 + $1.amount }

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
        hidesZeroBalances: Bool
    ) -> AssetListGroupViewModel? {
        let chain = groupModel.chain

        let assets = model.groupLists[chain.chainId] ?? []

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

        let assetInfoList: [AssetListAssetAccountInfo] = filteredAssets.map { asset in
            AssetListPresenterHelpers.createAssetAccountInfo(from: asset, chain: chain, maybePrices: maybePrices)
        }

        return viewModelFactory.createGroupViewModel(
            for: chain,
            assets: assetInfoList,
            value: groupModel.chainValue,
            connected: true,
            locale: selectedLocale
        )
    }

    private func provideNftViewModel() {
        guard !model.nfts.isEmpty else {
            view?.didReceiveNft(viewModel: nil)
            return
        }

        let nftViewModel = viewModelFactory.createNftsViewModel(from: model.nfts, locale: selectedLocale)
        view?.didReceiveNft(viewModel: nftViewModel)
    }

    private func updateAssetsView() {
        provideHeaderViewModel()
        provideAssetViewModels()
    }

    private func updateHeaderView() {
        provideHeaderViewModel()
    }

    private func updateNftView() {
        provideNftViewModel()
    }

    private func presentAssetDetails(for chainAssetId: ChainAssetId) {
        // get chain from interactor that includes also disabled assets
        let optChain = interactor.getFullChain(for: chainAssetId.chainId) ?? model.allChains[chainAssetId.chainId]

        guard
            let chain = optChain,
            let asset = chain.assets.first(where: { $0.assetId == chainAssetId.assetId }) else {
            return
        }

        wireframe.showAssetDetails(from: view, chain: chain, asset: asset)
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
        wireframe.showAssetsSearch(from: view, delegate: self)
    }

    func presentAssetsManage() {
        wireframe.showTokensManage(from: view)
    }

    func presentLocks() {
        guard
            checkNonZeroLocks(),
            let priceResult = model.priceResult,
            let prices = try? priceResult.get(),
            let locks = try? model.locksResult?.get(),
            let externalBalances = try? model.externalBalanceResult?.get() else {
            return
        }

        let params = LocksViewInput(
            prices: prices,
            balances: model.balances.values.compactMap { try? $0.get() },
            chains: model.allChains,
            locks: locks,
            externalBalances: externalBalances
        )

        wireframe.showBalanceBreakdown(from: view, params: params)
    }

    func send() {
        let transferCompletionClosure: TransferCompletionClosure = { [weak self] chainAsset in
            self?.wireframe.showAssetDetails(
                from: self?.view,
                chain: chainAsset.chain,
                asset: chainAsset.asset
            )
        }
        let buyTokensClosure: BuyTokensClosure = { [weak self] in
            self?.buy()
        }
        wireframe.showSendTokens(
            from: view,
            transferCompletion: transferCompletionClosure,
            buyTokensClosure: buyTokensClosure
        )
    }

    func receive() {
        wireframe.showRecieveTokens(from: view)
    }

    func buy() {
        wireframe.showBuyTokens(from: view)
    }

    func presentWalletConnect() {
        if walletConnectSessionsCount > 0 {
            wireframe.showWalletConnect(from: view)
        } else {
            wireframe.showScan(from: view, delegate: self)
        }
    }

    func selectPromotion() {
        shouldShowPolkadotPromotion = false
        interactor.markPolkadotStakingPromotionSeen()

        wireframe.showStaking(from: view)

        view?.didClosePromotion()
    }

    func closePromotion() {
        shouldShowPolkadotPromotion = false
        interactor.markPolkadotStakingPromotionSeen()

        view?.didClosePromotion()
    }
}

extension AssetListPresenter: AssetListInteractorOutputProtocol {
    func didReceive(result: AssetListBuilderResult) {
        guard result.walletId != nil, result.walletId == walletId else {
            return
        }

        model = result.model

        switch result.changeKind {
        case .reload:
            updateAssetsView()
        case .nfts:
            updateNftView()
        }
    }

    func didReceive(
        walletId: MetaAccountModel.Id,
        walletIdenticon: Data?,
        walletType: MetaAccountModelType,
        name: String
    ) {
        self.walletId = walletId
        self.walletIdenticon = walletIdenticon
        self.walletType = walletType
        self.name = name

        model = .init()

        updateAssetsView()
        updateNftView()
    }

    func didChange(name: String) {
        self.name = name

        updateHeaderView()
    }

    func didReceive(hidesZeroBalances: Bool) {
        self.hidesZeroBalances = hidesZeroBalances

        updateAssetsView()
    }

    func didReceiveWalletConnect(error: WalletConnectSessionsError) {
        switch error {
        case .connectionFailed:
            wireframe.presentWCConnectionError(from: view, locale: selectedLocale)
        case .sessionsFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryFetchWalletConnectSessionsCount()
            }
        }
    }

    func didReceiveWalletConnect(sessionsCount: Int) {
        walletConnectSessionsCount = sessionsCount
        updateHeaderView()
    }

    func didCompleteRefreshing() {
        view?.didCompleteRefreshing()
    }

    func didReceivePromotionBanner(shouldShowPolkadotStaking: Bool) {
        shouldShowPolkadotPromotion = shouldShowPolkadotStaking
        providePolkadotStakingPromotion()
    }
}

extension AssetListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateAssetsView()
            updateNftView()
            providePolkadotStakingPromotion()
        }
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
