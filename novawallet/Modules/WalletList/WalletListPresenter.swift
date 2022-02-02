import Foundation
import RobinHood
import SubstrateSdk
import SoraFoundation
import BigInt

final class WalletListPresenter {
    typealias ChainAssetPrice = (chainId: ChainModel.Id, assetId: AssetModel.Id, price: PriceData)

    weak var view: WalletListViewProtocol?
    let wireframe: WalletListWireframeProtocol
    let interactor: WalletListInteractorInputProtocol
    let viewModelFactory: WalletListViewModelFactoryProtocol

    private(set) var groups: ListDifferenceCalculator<WalletListGroupModel>
    private(set) var groupLists: [ChainModel.Id: ListDifferenceCalculator<WalletListAssetModel>] = [:]

    private var genericAccountId: AccountId?
    private var name: String?
    private(set) var connectionStates: [ChainModel.Id: WebSocketEngine.State] = [:]
    private(set) var priceResult: Result<[ChainAssetId: PriceData], Error>?
    private(set) var balanceResults: [ChainAssetId: Result<BigUInt, Error>] = [:]
    private(set) var allChains: [ChainModel.Id: ChainModel] = [:]

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
        self.localizationManager = localizationManager
    }

    private func provideHeaderViewModel() {
        guard let genericAccountId = genericAccountId, let name = name else {
            return
        }

        guard case let .success(priceMapping) = priceResult else {
            let viewModel = viewModelFactory.createHeaderViewModel(
                from: name,
                accountId: genericAccountId,
                prices: nil,
                locale: selectedLocale
            )

            view?.didReceiveHeader(viewModel: viewModel)
            return
        }

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
                    let asset = chain.assets.first(where: { $0.assetId == assetId }),
                    case let .success(balance) = balanceResults[chainAssetId] else {
                    return .cached(value: items)
                }

                let newItem = WalletListAssetAccountPrice(
                    assetInfo: asset.displayInfo,
                    balance: balance,
                    price: keyValue.value
                )

                return .cached(value: items + [newItem])
            case let .loaded(items):
                guard
                    let chain = allChains[chainId],
                    let asset = chain.assets.first(where: { $0.assetId == assetId }),
                    case let .success(balance) = balanceResults[chainAssetId] else {
                    return .cached(value: items)
                }

                let newItem = WalletListAssetAccountPrice(
                    assetInfo: asset.displayInfo,
                    balance: balance,
                    price: keyValue.value
                )

                return .loaded(value: items + [newItem])
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

    private func provideAssetViewModels() {
        let maybePrices = try? priceResult?.get()
        let viewModels: [WalletListGroupViewModel] = groups.allItems.compactMap { groupModel in
            let chain = groupModel.chain

            let assets = groupLists[chain.chainId]?.allItems ?? []

            let connected: Bool

            if let chainState = connectionStates[chain.chainId], case .connected = chainState {
                connected = true
            } else {
                connected = false
            }

            let assetInfoList: [WalletListAssetAccountInfo] = assets.map { asset in
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
                    assetInfo: assetInfo,
                    balance: balance,
                    priceData: priceData
                )
            }

            return viewModelFactory.createGroupViewModel(
                for: chain,
                assets: assetInfoList,
                value: groupModel.chainValue,
                connected: connected,
                locale: selectedLocale
            )
        }

        view?.didReceiveGroups(viewModels: viewModels)
    }
}

extension WalletListPresenter: WalletListPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func selectWallet() {
        wireframe.showWalletList(from: view)
    }

    func selectAsset(at index: Int, in group: Int) {
        let chainModel = groups.allItems[group].chain

        guard let assetListModel = groupLists[chainModel.chainId]?.allItems[index] else {
            return
        }

        wireframe.showAssetDetails(from: view, chain: chainModel, asset: assetListModel.assetModel)
    }

    func refresh() {
        interactor.refresh()
    }
}

extension WalletListPresenter: WalletListInteractorOutputProtocol {
    func didReceive(genericAccountId: AccountId, name: String) {
        self.genericAccountId = genericAccountId
        self.name = name

        allChains = [:]
        balanceResults = [:]

        if !groups.allItems.isEmpty || !groups.lastDifferences.isEmpty {
            groups = Self.createGroupsDiffCalculator(from: [])
            groupLists = [:]
        }

        provideHeaderViewModel()
        provideAssetViewModels()
    }

    func didReceive(state: WebSocketEngine.State, for chainId: ChainModel.Id) {
        connectionStates[chainId] = state

        provideHeaderViewModel()
        provideAssetViewModels()
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

        provideHeaderViewModel()
        provideAssetViewModels()
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

        provideHeaderViewModel()
        provideAssetViewModels()
    }

    func didReceiveBalance(result: Result<BigUInt, Error>, chainId: ChainModel.Id, assetId: AssetModel.Id) {
        let chainAssetId = ChainAssetId(chainId: chainId, assetId: assetId)
        balanceResults[chainAssetId] = result

        guard
            let chainModel = allChains[chainId],
            let assetModel = chainModel.assets.first(where: { $0.assetId == assetId }) else {
            return
        }

        let assetListModel = createAssetModel(for: chainModel, assetModel: assetModel)
        groupLists[chainId]?.apply(changes: [.update(newItem: assetListModel)])

        let allListAssets = groupLists[chainId]?.allItems ?? []
        let groupsModel = createGroupModel(from: chainModel, assets: allListAssets)

        groups.apply(changes: [.update(newItem: groupsModel)])

        provideHeaderViewModel()
        provideAssetViewModels()
    }

    func didChange(name: String) {
        self.name = name

        provideHeaderViewModel()
    }
}

extension WalletListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideHeaderViewModel()
        }
    }
}
