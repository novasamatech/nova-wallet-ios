import Foundation
import RobinHood
import SubstrateSdk
import SoraFoundation
import BigInt
import CommonWallet

final class WalletListPresenter {
    static let viewUpdatePeriod: TimeInterval = 1.0

    typealias ChainAssetPrice = (chainId: ChainModel.Id, assetId: AssetModel.Id, price: PriceData)

    weak var view: WalletListViewProtocol?
    let wireframe: WalletListWireframeProtocol
    let interactor: WalletListInteractorInputProtocol
    let viewModelFactory: WalletListViewModelFactoryProtocol

    private(set) var groups: ListDifferenceCalculator<WalletListGroupModel>
    private(set) var groupLists: [ChainModel.Id: ListDifferenceCalculator<WalletListAssetModel>] = [:]

    private(set) var nftList: ListDifferenceCalculator<NftModel>

    private var genericAccountId: AccountId?
    private var name: String?
    private var hidesZeroBalances: Bool?
    private(set) var connectionStates: [ChainModel.Id: WebSocketEngine.State] = [:]
    private(set) var priceResult: Result<[ChainAssetId: PriceData], Error>?
    private(set) var balanceResults: [ChainAssetId: Result<BigUInt, Error>] = [:]
    private(set) var allChains: [ChainModel.Id: ChainModel] = [:]

    private var scheduler: SchedulerProtocol?

    deinit {
        cancelViewUpdate()
    }

    init(
        interactor: WalletListInteractorInputProtocol,
        wireframe: WalletListWireframeProtocol,
        viewModelFactory: WalletListViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        groups = Self.createGroupsDiffCalculator(from: [])
        nftList = Self.createNftDiffCalculator()
        self.localizationManager = localizationManager
    }

    private func provideHeaderViewModel() {
        guard let genericAccountId = genericAccountId, let name = name else {
            return
        }

        guard case let .success(priceMapping) = priceResult, !balanceResults.isEmpty else {
            let viewModel = viewModelFactory.createHeaderViewModel(
                from: name,
                accountId: genericAccountId,
                prices: nil,
                locale: selectedLocale
            )

            view?.didReceiveHeader(viewModel: viewModel)
            return
        }

        provideHeaderViewModel(with: priceMapping, genericAccountId: genericAccountId, name: name)
    }

    private func provideHeaderViewModel(
        with priceMapping: [ChainAssetId: PriceData],
        genericAccountId: AccountId,
        name: String
    ) {
        let priceState: LoadableViewModelState<[WalletListAssetAccountPrice]> = priceMapping.reduce(
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

                let newItem = WalletListAssetAccountPrice(
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
                    let newItem = WalletListAssetAccountPrice(
                        assetInfo: asset.displayInfo,
                        balance: assetBalance,
                        price: keyValue.value
                    )

                    return .loaded(value: items + [newItem])
                } else {
                    let newItem = WalletListAssetAccountPrice(
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
        let viewModels: [WalletListGroupViewModel] = groups.allItems.compactMap { groupModel in
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
        from groupModel: WalletListGroupModel,
        maybePrices: [ChainAssetId: PriceData]?,
        hidesZeroBalances: Bool
    ) -> WalletListGroupViewModel? {
        let chain = groupModel.chain

        let assets = groupLists[chain.chainId]?.allItems ?? []

        let filteredAssets: [WalletListAssetModel]

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

        let assetInfoList: [WalletListAssetAccountInfo] = filteredAssets.map { asset in
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

    private func createAssetAccountInfo(
        from asset: WalletListAssetModel,
        chain: ChainModel,
        maybePrices: [ChainAssetId: PriceData]?
    ) -> WalletListAssetAccountInfo {
        let assetModel = asset.assetModel
        let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: assetModel.assetId)

        let assetInfo = assetModel.displayInfo(with: chain.icon)

        let priceData: PriceData?

        if let prices = maybePrices {
            priceData = prices[chainAssetId] ?? PriceData(price: "0", usdDayChange: 0)
        } else {
            priceData = nil
        }

        let balance = try? asset.balanceResult?.get()

        return WalletListAssetAccountInfo(
            assetId: asset.assetModel.assetId,
            assetInfo: assetInfo,
            balance: balance,
            priceData: priceData
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
}

extension WalletListPresenter: WalletListPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func selectWallet() {
        wireframe.showWalletList(from: view)
    }

    func selectAsset(for chainAssetId: ChainAssetId) {
        guard
            let chain = allChains[chainAssetId.chainId],
            let asset = chain.assets.first(where: { $0.assetId == chainAssetId.assetId }) else {
            return
        }

        wireframe.showAssetDetails(from: view, chain: chain, asset: asset)
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
}

extension WalletListPresenter: WalletListInteractorOutputProtocol {
    func didReceiveNft(changes: [DataProviderChange<NftModel>]) {
        nftList.apply(changes: changes)

        updateNftView()
    }

    func didReceiveNft(error _: Error) {}

    func didResetNftProvider() {
        nftList = Self.createNftDiffCalculator()
    }

    func didReceive(genericAccountId: AccountId, name: String) {
        self.genericAccountId = genericAccountId
        self.name = name

        allChains = [:]
        balanceResults = [:]

        groups = Self.createGroupsDiffCalculator(from: [])
        groupLists = [:]

        nftList = Self.createNftDiffCalculator()

        updateAssetsView()
        updateNftView()
    }

    func didReceive(state: WebSocketEngine.State, for chainId: ChainModel.Id) {
        connectionStates[chainId] = state

        scheduleViewUpdate()
    }

    func didReceivePrices(result: Result<[ChainAssetId: PriceData], Error>?) {
        view?.didCompleteRefreshing()

        guard let result = result else {
            return
        }

        priceResult = result

        for chain in allChains.values {
            let models = chain.assets.map { asset in
                createAssetModel(for: chain, assetModel: asset)
            }

            let changes: [DataProviderChange<WalletListAssetModel>] = models.map { model in
                .update(newItem: model)
            }

            groupLists[chain.chainId]?.apply(changes: changes)

            let groupModel = createGroupModel(from: chain, assets: models)
            groups.apply(changes: [.update(newItem: groupModel)])
        }

        updateAssetsView()
    }

    func didReceiveChainModelChanges(_ changes: [DataProviderChange<ChainModel>]) {
        var groupChanges: [DataProviderChange<WalletListGroupModel>] = []
        for change in changes {
            switch change {
            case let .insert(newItem):
                let assets = createAssetModels(for: newItem)
                let assetsCalculator = Self.createAssetsDiffCalculator(from: assets)
                groupLists[newItem.chainId] = assetsCalculator

                let groupModel = createGroupModel(from: newItem, assets: assets)
                groupChanges.append(.insert(newItem: groupModel))
            case let .update(newItem):
                let assets = createAssetModels(for: newItem)

                groupLists[newItem.chainId] = Self.createAssetsDiffCalculator(from: assets)

                let groupModel = createGroupModel(from: newItem, assets: assets)
                groupChanges.append(.update(newItem: groupModel))

            case let .delete(deletedIdentifier):
                groupLists[deletedIdentifier] = nil
                groupChanges.append(.delete(deletedIdentifier: deletedIdentifier))
            }
        }

        allChains = changes.reduce(into: allChains) { result, change in
            switch change {
            case let .insert(newItem):
                result[newItem.chainId] = newItem
            case let .update(newItem):
                result[newItem.chainId] = newItem
            case let .delete(deletedIdentifier):
                result[deletedIdentifier] = nil
            }
        }

        groups.apply(changes: groupChanges)

        updateAssetsView()
    }

    func didReceiveBalance(results: [ChainAssetId: Result<BigUInt?, Error>]) {
        var assetsChanges: [ChainModel.Id: [DataProviderChange<WalletListAssetModel>]] = [:]
        var changedGroups: [ChainModel.Id: ChainModel] = [:]

        for (chainAssetId, result) in results {
            switch result {
            case let .success(maybeAmount):
                if let amount = maybeAmount {
                    balanceResults[chainAssetId] = .success(amount)
                } else if balanceResults[chainAssetId] == nil {
                    balanceResults[chainAssetId] = .success(0)
                }
            case let .failure(error):
                balanceResults[chainAssetId] = .failure(error)
            }
        }

        for chainAssetId in results.keys {
            guard
                let chainModel = allChains[chainAssetId.chainId],
                let assetModel = chainModel.assets.first(
                    where: { $0.assetId == chainAssetId.assetId }
                ) else {
                continue
            }

            let assetListModel = createAssetModel(for: chainModel, assetModel: assetModel)
            var chainChanges = assetsChanges[chainAssetId.chainId] ?? []
            chainChanges.append(.update(newItem: assetListModel))
            assetsChanges[chainAssetId.chainId] = chainChanges

            changedGroups[chainModel.chainId] = chainModel
        }

        for (chainId, changes) in assetsChanges {
            groupLists[chainId]?.apply(changes: changes)
        }

        let groupChanges: [DataProviderChange<WalletListGroupModel>] = changedGroups.map { keyValue in
            let chainId = keyValue.key
            let chainModel = keyValue.value

            let allItems = groupLists[chainId]?.allItems ?? []
            let groupModel = createGroupModel(from: chainModel, assets: allItems)

            return .update(newItem: groupModel)
        }

        groups.apply(changes: groupChanges)

        updateAssetsView()
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

extension WalletListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateAssetsView()
            updateNftView()
        }
    }
}

extension WalletListPresenter: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        updateAssetsView()
    }
}
