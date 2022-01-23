import Foundation
import RobinHood
import SubstrateSdk
import SoraFoundation
import BigInt

final class WalletListPresenter {
    typealias ChainAssetPrice = (chainId: ChainModel.Id, assetId: AssetModel.Id, price: PriceData)

    struct ListModel: Identifiable {
        static func createIdentifier(chainId: ChainModel.Id, assetId: AssetModel.Id) -> String {
            "\(chainId)-\(assetId)"
        }

        var identifier: String {
            Self.createIdentifier(chainId: chainModel.chainId, assetId: assetModel.assetId)
        }

        let chainModel: ChainModel
        let assetModel: AssetModel
        let balanceResult: Result<BigUInt, Error>?
        let value: Decimal?
    }

    weak var view: WalletListViewProtocol?
    let wireframe: WalletListWireframeProtocol
    let interactor: WalletListInteractorInputProtocol
    let viewModelFactory: WalletListViewModelFactoryProtocol

    private var chainList: ListDifferenceCalculator<ListModel>

    private var genericAccountId: AccountId?
    private var name: String?
    private var connectionStates: [ChainModel.Id: WebSocketEngine.State] = [:]
    private var priceResult: Result<[ChainAssetId: PriceData], Error>?
    private var balanceResults: [ChainAssetId: Result<BigUInt, Error>] = [:]
    private var allChains: [ChainModel.Id: ChainModel] = [:]

    init(
        interactor: WalletListInteractorInputProtocol,
        wireframe: WalletListWireframeProtocol,
        viewModelFactory: WalletListViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        chainList = Self.createChainList()
        self.localizationManager = localizationManager
    }

    static func createChainList() -> ListDifferenceCalculator<ListModel> {
        ListDifferenceCalculator(
            initialItems: [],
            sortBlock: { model1, model2 in
                let balance1 = (try? model1.balanceResult?.get()) ?? 0
                let balance2 = (try? model2.balanceResult?.get()) ?? 0

                let value1 = model1.value ?? 0
                let value2 = model2.value ?? 0

                if value1 > 0, value2 > 0 {
                    return value1 > value2
                } else if value1 > 0 {
                    return true
                } else if value2 > 0 {
                    return false
                } else if balance1 > 0, balance2 > 0 {
                    return model1.chainModel.order < model2.chainModel.order
                } else if balance1 > 0 {
                    return true
                } else if balance2 > 0 {
                    return false
                } else {
                    return model1.chainModel.order < model2.chainModel.order
                }
            }
        )
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

        let priceState: LoadableViewModelState<[WalletListChainAccountPrice]> = priceMapping.reduce(
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

                let newItem = WalletListChainAccountPrice(
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

                let newItem = WalletListChainAccountPrice(
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

    private func createListModels(for chainModel: ChainModel) -> [ListModel] {
        chainModel.assets.map { createListModel(for: chainModel, assetModel: $0) }
    }

    private func createListModel(for chainModel: ChainModel, assetModel: AssetModel) -> ListModel {
        let chainAssetId = ChainAssetId(chainId: chainModel.chainId, assetId: assetModel.assetId)
        let balanceResult = balanceResults[chainAssetId]

        let maybeBalance: Decimal? = {
            if let balance = try? balanceResult?.get() {
                return Decimal.fromSubstrateAmount(
                    balance,
                    precision: Int16(bitPattern: assetModel.precision)
                )
            } else {
                return nil
            }
        }()

        let maybePrice: Decimal? = {
            if let mapping = try? priceResult?.get(), let priceData = mapping[chainAssetId] {
                return Decimal(string: priceData.price)
            } else {
                return nil
            }
        }()

        if let balance = maybeBalance, let price = maybePrice {
            return ListModel(
                chainModel: chainModel,
                assetModel: assetModel,
                balanceResult: balanceResult,
                value: balance * price
            )
        } else {
            return ListModel(
                chainModel: chainModel,
                assetModel: assetModel,
                balanceResult: balanceResult,
                value: nil
            )
        }
    }

    private func provideAssetViewModels() {
        let maybePrices = try? priceResult?.get()
        let viewModels: [WalletListViewModel] = chainList.allItems.compactMap { listModel in
            let chain = listModel.chainModel
            let asset = listModel.assetModel
            let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)

            let assetInfo = asset.displayInfo(with: chain.icon)

            let connected: Bool

            if let chainState = connectionStates[chain.chainId], case .connected = chainState {
                connected = true
            } else {
                connected = false
            }

            let priceData: PriceData?

            if let prices = maybePrices {
                priceData = prices[chainAssetId] ?? PriceData(price: "0", usdDayChange: 0)
            } else {
                priceData = nil
            }

            let balance = try? listModel.balanceResult?.get()

            return viewModelFactory.createAssetViewModel(
                for: chain,
                assetInfo: assetInfo,
                balance: balance,
                priceData: priceData,
                connected: connected,
                locale: selectedLocale
            )
        }

        view?.didReceiveAssets(viewModel: viewModels)
    }
}

extension WalletListPresenter: WalletListPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func selectWallet() {
        wireframe.showWalletList(from: view)
    }

    func selectAsset(at index: Int) {
        let chainModel = chainList.allItems[index].chainModel
        let assetModel = chainList.allItems[index].assetModel
        wireframe.showAssetDetails(from: view, chain: chainModel, asset: assetModel)
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

        if !chainList.allItems.isEmpty || !chainList.lastDifferences.isEmpty {
            chainList = Self.createChainList()
        }

        provideHeaderViewModel()
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

        let changes: [DataProviderChange<ListModel>] = allChains.values.flatMap { chain in
            chain.assets.map { asset in
                let model = createListModel(for: chain, assetModel: asset)
                return .update(newItem: model)
            }
        }

        chainList.apply(changes: changes)

        provideHeaderViewModel()
        provideAssetViewModels()
    }

    func didReceiveChainModelChanges(_ changes: [DataProviderChange<ChainModel>]) {
        let listChanges: [DataProviderChange<ListModel>] = changes
            .flatMap { (change) -> [DataProviderChange<ListModel>] in
                switch change {
                case let .insert(newItem):
                    let models = createListModels(for: newItem)
                    return models.map { DataProviderChange.insert(newItem: $0) }
                case let .update(newItem):
                    let removals: [DataProviderChange<ListModel>]

                    if let previousChain = allChains[newItem.chainId] {
                        removals = previousChain.assets.map { asset in
                            let identifier = ListModel.createIdentifier(
                                chainId: previousChain.chainId,
                                assetId: asset.assetId
                            )

                            return DataProviderChange.delete(deletedIdentifier: identifier)
                        }
                    } else {
                        removals = []
                    }

                    let models = createListModels(for: newItem)
                    let insertions = models.map { DataProviderChange.insert(newItem: $0) }

                    return removals + insertions
                case let .delete(deletedIdentifier):
                    if let previousChain = allChains[deletedIdentifier] {
                        return previousChain.assets.map { asset in
                            let identifier = ListModel.createIdentifier(
                                chainId: previousChain.chainId,
                                assetId: asset.assetId
                            )

                            return DataProviderChange.delete(deletedIdentifier: identifier)
                        }
                    } else {
                        return []
                    }
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

        chainList.apply(changes: listChanges)

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

        let listModel = createListModel(for: chainModel, assetModel: assetModel)
        chainList.apply(changes: [.update(newItem: listModel)])

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
