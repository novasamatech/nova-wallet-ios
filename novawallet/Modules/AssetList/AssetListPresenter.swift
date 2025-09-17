import Foundation
import Operation_iOS
import SubstrateSdk
import Foundation_iOS
import BigInt

final class AssetListPresenter: RampFlowManaging, BannersModuleInputOwnerProtocol {
    typealias SuccessAssetListAssetAccountPrice = AssetListAssetAccountPrice
    typealias FailedAssetListAssetAccountPrice = AssetListAssetAccountPrice

    static let viewUpdatePeriod: TimeInterval = 1.0

    weak var view: AssetListViewProtocol?
    weak var bannersModule: BannersModuleInputProtocol?

    let wireframe: AssetListWireframeProtocol
    let interactor: AssetListInteractorInputProtocol
    let viewModelFactory: AssetListViewModelFactoryProtocol
    let privacyStateManager: PrivacyStateManagerProtocol

    private var wallet: MetaAccountModel?

    private var walletIdenticon: Data?

    private var walletId: MetaAccountModel.Id? {
        wallet?.identifier
    }

    private var walletType: MetaAccountModelType? {
        wallet?.type
    }

    private var name: String?

    private var hidesZeroBalances: Bool?
    private var hasWalletsUpdates: Bool = false
    private var privacyModeEnabled: Bool = false

    private var organizerViewModel: AssetListOrganizerViewModel?

    private(set) var walletConnectSessionsCount: Int = 0

    private(set) var assetListStyle: AssetListGroupsStyle?

    private(set) var model: AssetListBuilderResult.Model = .init()

    init(
        interactor: AssetListInteractorInputProtocol,
        wireframe: AssetListWireframeProtocol,
        viewModelFactory: AssetListViewModelFactoryProtocol,
        privacyStateManager: PrivacyStateManagerProtocol,
        localizationManager: LocalizationManagerProtocol,
        appearanceFacade: AppearanceFacadeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.privacyStateManager = privacyStateManager
        self.localizationManager = localizationManager
        self.appearanceFacade = appearanceFacade
    }
}

// MARK: Private

private extension AssetListPresenter {
    func provideBanners(state: BannersState) {
        let available = state == .available || state == .loading
        view?.didReceiveBanners(available: available)
    }

    func provideHeaderViewModel() {
        guard
            let walletId = walletId,
            let walletType = walletType,
            let name = name else {
            return
        }

        guard case let .success(priceMapping) = model.priceResult, !model.balanceResults.isEmpty else {
            let viewModel = viewModelFactory.createHeaderViewModel(
                params: .init(
                    title: name,
                    wallet: .init(
                        identifier: walletId,
                        walletIdenticon: walletIdenticon,
                        walletType: walletType,
                        walletConnectSessionsCount: walletConnectSessionsCount,
                        hasWalletsUpdates: hasWalletsUpdates
                    ),
                    prices: nil,
                    locks: nil,
                    hasSwaps: model.hasSwaps(),
                    privacyModeEnabled: privacyModeEnabled
                ),
                locale: selectedLocale
            )

            view?.didReceiveHeader(viewModel: viewModel)
            return
        }

        provideHeaderViewModel(
            with: walletId,
            priceMapping: priceMapping,
            walletIdenticon: walletIdenticon,
            walletType: walletType,
            name: name
        )
    }

    func createAssetAccountPrice(
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

    func createAssetAccountPriceLock(
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

    func provideHeaderViewModel(
        with walletId: String,
        priceMapping: [ChainAssetId: PriceData],
        walletIdenticon: Data?,
        walletType: MetaAccountModelType,
        name: String
    ) {
        let externalBalances = externalBalanceModel(prices: priceMapping)
        let totalValue = createHeaderPriceState(from: priceMapping, externalBalances: externalBalances)
        let totalLocks = createHeaderLockState(from: priceMapping, externalBalances: externalBalances)

        let viewModel = viewModelFactory.createHeaderViewModel(
            params: .init(
                title: name,
                wallet: .init(
                    identifier: walletId,
                    walletIdenticon: walletIdenticon,
                    walletType: walletType,
                    walletConnectSessionsCount: walletConnectSessionsCount,
                    hasWalletsUpdates: hasWalletsUpdates
                ),
                prices: totalValue,
                locks: totalLocks,
                hasSwaps: model.hasSwaps(),
                privacyModeEnabled: privacyModeEnabled
            ),
            locale: selectedLocale
        )

        view?.didReceiveHeader(viewModel: viewModel)
    }

    func createHeaderPriceState(
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

    func createHeaderLockState(
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

    func checkNonZeroLocks() -> Bool {
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

    func provideAssetViewModels() {
        guard let hidesZeroBalances, let assetListStyle else {
            return
        }

        let viewModels = createGroupViewModels()

        let isFilterOn = hidesZeroBalances == true
        if viewModels.isEmpty, !model.balanceResults.isEmpty, model.balanceResults.count >= model.allChains.count {
            view?.didReceiveGroups(viewModel: .init(
                isFiltered: isFilterOn,
                listState: .empty,
                listGroupStyle: assetListStyle
            ))
        } else {
            view?.didReceiveGroups(viewModel: .init(
                isFiltered: isFilterOn,
                listState: .list(groups: viewModels),
                listGroupStyle: assetListStyle
            ))
        }
    }

    func externalBalanceModel(prices: [ChainAssetId: PriceData]) -> [AssetListAssetAccountPrice] {
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

    func createGroupViewModels() -> [AssetListGroupType] {
        guard let hidesZeroBalances, let assetListStyle else {
            return []
        }

        let maybePrices = try? model.priceResult?.get()

        return switch assetListStyle {
        case .networks:
            model.chainGroups.compactMap {
                createNetworkGroupViewModel(
                    from: $0,
                    maybePrices: maybePrices,
                    hidesZeroBalances: hidesZeroBalances
                )
            }
        case .tokens:
            model.assetGroups.compactMap {
                createAssetGroupViewModel(
                    from: $0,
                    maybePrices: maybePrices,
                    hidesZeroBalances: hidesZeroBalances
                )
            }
        }
    }

    func filterZeroBalances(_ assets: [AssetListAssetModel]) -> [AssetListAssetModel] {
        let filteredAssets: [AssetListAssetModel]

        filteredAssets = assets.filter { asset in
            if let balance = try? asset.balanceResult?.get(), balance > 0 {
                return true
            } else {
                return false
            }
        }

        return filteredAssets
    }

    func createAssetGroupViewModel(
        from groupModel: AssetListAssetGroupModel,
        maybePrices: [ChainAssetId: PriceData]?,
        hidesZeroBalances: Bool
    ) -> AssetListGroupType? {
        let assets = model.groupListsByAsset[groupModel.multichainToken.symbol] ?? []

        let filteredAssets = hidesZeroBalances
            ? filterZeroBalances(assets)
            : assets

        guard !filteredAssets.isEmpty else {
            return nil
        }

        let params = AssetListTokenGroupViewModelParams(
            assetsList: filteredAssets,
            group: groupModel,
            maybePrices: maybePrices,
            privacyModeEnabled: privacyModeEnabled,
            connected: true
        )

        return if let groupViewModel = viewModelFactory.createTokenGroupViewModel(
            params: params,
            locale: selectedLocale
        ) {
            .token(groupViewModel)
        } else {
            nil
        }
    }

    func createNetworkGroupViewModel(
        from groupModel: AssetListChainGroupModel,
        maybePrices: [ChainAssetId: PriceData]?,
        hidesZeroBalances: Bool
    ) -> AssetListGroupType? {
        let chain = groupModel.chain

        let assets = model.groupListsByChain[chain.chainId] ?? []

        let filteredAssets = hidesZeroBalances
            ? filterZeroBalances(assets)
            : assets

        guard !filteredAssets.isEmpty else {
            return nil
        }

        let assetInfoList: [AssetListAssetAccountInfo] = filteredAssets.map { asset in
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
            privacyModeEnabled: privacyModeEnabled,
            connected: true
        )
        return .network(
            viewModelFactory.createNetworkGroupViewModel(
                params: params,
                locale: selectedLocale
            )
        )
    }

    func provideOrganizerViewModel() {
        let viewModel = viewModelFactory.createOrganizerViewModel(
            from: model.nfts,
            operations: model.pendingOperations,
            privacyModeEnabled: privacyModeEnabled,
            locale: selectedLocale
        )

        guard organizerViewModel != viewModel else {
            return
        }

        organizerViewModel = viewModel

        view?.didReceiveOrganizer(viewModel: viewModel)
    }

    func updateAssetsView() {
        provideHeaderViewModel()
        provideAssetViewModels()
    }

    func updateHeaderView() {
        provideHeaderViewModel()
    }

    func updateOrganizerView() {
        provideOrganizerViewModel()
    }

    func presentAssetDetails(for chainAssetId: ChainAssetId) {
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

// MARK: AssetListPresenterProtocol

extension AssetListPresenter: AssetListPresenterProtocol {
    func selectOrganizerItem(at index: Int) {
        guard
            let organizerViewModel,
            organizerViewModel.items.count > index
        else { return }

        let item = organizerViewModel.items[index]

        switch item {
        case .nfts:
            wireframe.showNfts(from: view)
        case .pendingTransactions:
            wireframe.showMultisigOperations(from: view)
        }
    }

    func setup() {
        if let bannersModule {
            provideBanners(state: bannersModule.bannersState)
        }

        interactor.setup()

        privacyStateManager.addObserver(
            with: self,
            queue: .main
        ) { [weak self] _, privacyModeEnabled in
            guard self?.privacyModeEnabled != privacyModeEnabled else { return }

            self?.privacyModeEnabled = privacyModeEnabled

            self?.provideHeaderViewModel()
            self?.provideAssetViewModels()
            self?.provideOrganizerViewModel()
        }
    }

    func selectWallet() {
        wireframe.showWalletSwitch(from: view)
    }

    func selectAsset(for chainAssetId: ChainAssetId) {
        presentAssetDetails(for: chainAssetId)
    }

    func refresh() {
        interactor.refresh()
        bannersModule?.refresh()
    }

    func presentSearch() {
        wireframe.showAssetsSearch(from: view, delegate: self)
    }

    func presentAssetsManage() {
        wireframe.showTokensManage(from: view)
    }

    func presentCard() {
        guard let wallet else { return }

        wireframe.showCard(
            from: view,
            wallet: wallet
        )
    }

    func presentLocks() {
        guard
            checkNonZeroLocks(),
            let priceResult = model.priceResult,
            let prices = try? priceResult.get(),
            let locks = try? model.locksResult?.get(),
            let holds = try? model.holdsResult?.get(),
            let externalBalances = try? model.externalBalanceResult?.get() else {
            return
        }

        let params = LocksViewInput(
            prices: prices,
            balances: model.balances.values.compactMap { try? $0.get() },
            chains: model.allChains,
            locks: locks,
            holds: holds,
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
            guard let self, let wallet else { return }

            wireframe.showRamp(
                from: view,
                action: .onRamp,
                delegate: self
            )
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

    func buySell() {
        wireframe.presentRampActionsSheet(
            from: view,
            availableOptions: .init([.onRamp, .offRamp]),
            delegate: self,
            locale: selectedLocale
        ) { [weak self] rampAction in
            guard let self, let wallet else { return }

            wireframe.showRamp(
                from: view,
                action: rampAction,
                delegate: self
            )
        }
    }

    func swap() {
        wireframe.showSwapTokens(from: view)
    }

    func presentWalletConnect() {
        if walletConnectSessionsCount > 0 {
            wireframe.showWalletConnect(from: view)
        } else {
            wireframe.showScan(from: view, delegate: self)
        }
    }

    func toggleAssetListStyle() {
        assetListStyle?.toggle()

        guard let assetListStyle else {
            return
        }

        provideAssetViewModels()
        interactor.setAssetListGroupsStyle(assetListStyle)
    }

    func togglePrivacyMode() {
        privacyStateManager.lastEnabled.toggle()
    }
}

// MARK: AssetListInteractorOutputProtocol

extension AssetListPresenter: AssetListInteractorOutputProtocol {
    func didReceive(result: AssetListBuilderResult) {
        guard result.walletId != nil, result.walletId == walletId else {
            return
        }

        model = result.model

        switch result.changeKind {
        case .reload:
            updateAssetsView()
        case .nfts, .pendingOperations:
            updateOrganizerView()
        }
    }

    func didReceive(wallet: MetaAccountModel) {
        self.wallet = wallet

        name = wallet.name
        walletIdenticon = wallet.walletIdenticonData()

        model = .init()

        updateAssetsView()
        updateOrganizerView()
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
        case let .connectionFailed(internalError):
            wireframe.presentWCConnectionError(from: view, error: internalError, locale: selectedLocale)
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

    func didReceiveWalletsState(hasUpdates: Bool) {
        hasWalletsUpdates = hasUpdates
        provideHeaderViewModel()
    }

    func didReceiveAssetListGroupStyle(_ style: AssetListGroupsStyle) {
        assetListStyle = style

        view?.didReceiveAssetListStyle(style)
    }
}

// MARK: BannersModuleOutputProtocol

extension AssetListPresenter: BannersModuleOutputProtocol {
    func didReceive(_ error: any Error) {
        wireframe.present(
            error: error,
            from: view,
            locale: selectedLocale
        )
    }

    func didReceiveBanners(state: BannersState) {
        provideBanners(state: state)
    }

    func didUpdateContent(state: BannersState) {
        provideBanners(state: state)
    }
}

// MARK: ModalPickerViewControllerDelegate

extension AssetListPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let modalPickerContext = context as? ModalPickerClosureContext else {
            return
        }

        modalPickerContext.process(selectedIndex: index)
    }
}

// MARK: RampFlowStartingDelegate

extension AssetListPresenter: RampFlowStartingDelegate {
    func didPickRampParams(
        actions: [RampAction],
        rampType: RampActionType,
        chainAsset: ChainAsset
    ) {
        wireframe.dropModalFlow(from: view) { [weak self] in
            guard let self else { return }

            startRampFlow(
                from: view,
                actions: actions,
                rampType: rampType,
                wireframe: wireframe,
                chainAsset: chainAsset,
                locale: selectedLocale
            )
        }
    }
}

// MARK: RampDelegate

extension AssetListPresenter: RampDelegate {
    func rampDidComplete(
        action: RampActionType,
        chainAsset: ChainAsset
    ) {
        wireframe.dropModalFlow(from: view) { [weak self] in
            guard let self else { return }

            wireframe.showAssetDetails(
                from: view,
                chain: chainAsset.chain,
                asset: chainAsset.asset
            )
            wireframe.presentRampDidComplete(
                view: view,
                action: action,
                locale: selectedLocale
            )
        }
    }
}

// MARK: Localizable

extension AssetListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateAssetsView()
            updateOrganizerView()
            bannersModule?.updateLocale(selectedLocale)
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

extension AssetListPresenter: IconAppearanceDepending {
    func applyIconAppearance() {
        guard let view, view.isSetup else { return }

        provideAssetViewModels()
        updateOrganizerView()
    }
}
