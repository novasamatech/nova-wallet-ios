import Foundation
import RobinHood
import SubstrateSdk
import SoraFoundation
import BigInt

final class WalletListPresenter {
    struct ListModel: Identifiable {
        var identifier: String { chainModel.chainId }

        let chainModel: ChainModel
        let accountInfoResult: Result<AccountInfo?, Error>?
        let value: Decimal?
    }

    weak var view: WalletListViewProtocol?
    let wireframe: WalletListWireframeProtocol
    let interactor: WalletListInteractorInputProtocol
    let viewModelFactory: WalletListViewModelFactoryProtocol

    private var connectionListDifference: ListDifferenceCalculator<ListModel> = ListDifferenceCalculator(
        initialItems: [],
        sortBlock: { model1, model2 in
            let balance1 = try? model1.accountInfoResult?.get()?.data.total
            let balance2 = try? model2.accountInfoResult?.get()?.data.total

            let value1 = model1.value
            let value2 = model2.value

            if value1 != nil, value2 != nil {
                return model1.chainModel.order < model2.chainModel.order
            } else if value1 != nil {
                return true
            } else if value2 != nil {
                return false
            } else if balance1 != nil, balance2 != nil {
                return model1.chainModel.order < model2.chainModel.order
            } else if balance1 != nil {
                return true
            } else if balance2 != nil {
                return false
            } else {
                return model1.chainModel.order < model2.chainModel.order
            }
        }
    )

    private var genericAccountId: AccountId?
    private var name: String?
    private var connectionStates: [ChainModel.Id: WebSocketEngine.State] = [:]
    private var priceResult: Result<[ChainModel.Id: PriceData], Error>?
    private var accountResults: [ChainModel.Id: Result<AccountInfo?, Error>] = [:]
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

        let priceState: LoadableViewModelState<[WalletListChainAccountPrice]> = priceMapping.reduce(
            LoadableViewModelState.loaded(value: [])
        ) { result, keyValue in
            let chainId = keyValue.key
            switch result {
            case .loading:
                return .loading
            case let .cached(items):
                guard
                    let chain = allChains[chainId],
                    let asset = chain.utilityAssets().first,
                    case let .success(maybeAccountInfo) = accountResults[chainId] else {
                    return .cached(value: items)
                }

                if let accountInfo = maybeAccountInfo {
                    let newItem = WalletListChainAccountPrice(
                        assetInfo: asset.displayInfo,
                        accountInfo: accountInfo,
                        price: keyValue.value
                    )

                    return .cached(value: items + [newItem])
                } else {
                    return .cached(value: items)
                }
            case let .loaded(items):
                guard
                    let chain = allChains[chainId],
                    let asset = chain.utilityAssets().first,
                    case let .success(maybeAccountInfo) = accountResults[chainId] else {
                    return .cached(value: items)
                }

                if let accountInfo = maybeAccountInfo {
                    let newItem = WalletListChainAccountPrice(
                        assetInfo: asset.displayInfo,
                        accountInfo: accountInfo,
                        price: keyValue.value
                    )

                    return .loaded(value: items + [newItem])
                } else {
                    return .loaded(value: items)
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

    private func createListModel(for chainModel: ChainModel) -> ListModel {
        let accountInfo = accountResults[chainModel.chainId]

        let maybeBalance: Decimal? = {
            if
                let total = try? accountInfo?.get()?.data.total,
                let asset = chainModel.utilityAssets().first {
                return Decimal.fromSubstrateAmount(total, precision: Int16(bitPattern: asset.precision))
            } else {
                return nil
            }
        }()

        let maybePrice: Decimal? = {
            if
                let mapping = try? priceResult?.get(), let priceData = mapping[chainModel.chainId] {
                return Decimal(string: priceData.price)
            } else {
                return nil
            }
        }()

        if let balance = maybeBalance, let price = maybePrice {
            return ListModel(chainModel: chainModel, accountInfoResult: accountInfo, value: balance * price)
        } else {
            return ListModel(chainModel: chainModel, accountInfoResult: accountInfo, value: nil)
        }
    }

    private func provideAssetViewModels() {
        let maybePrices = try? priceResult?.get()
        let viewModels: [WalletListViewModel] = connectionListDifference.allItems.compactMap { model in
            let chain = model.chainModel
            guard let assetInfo = chain.utilityAssets().first?.displayInfo(with: chain.icon) else {
                return nil
            }

            let connected: Bool

            if let chainState = connectionStates[chain.chainId], case .connected = chainState {
                connected = true
            } else {
                connected = false
            }

            let balance: BigUInt?

            switch model.accountInfoResult {
            case let .success(accountInfo):
                balance = accountInfo?.data.total ?? 0
            case .failure, .none:
                balance = nil
            }

            let priceData: PriceData?

            if let prices = maybePrices {
                priceData = prices[chain.chainId] ?? PriceData(price: "0", usdDayChange: 0)
            } else {
                priceData = nil
            }

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
        let chainModel = connectionListDifference.allItems[index].chainModel
        wireframe.showAssetDetails(from: view, chain: chainModel)
    }
}

extension WalletListPresenter: WalletListInteractorOutputProtocol {
    func didReceive(genericAccountId: AccountId, name: String) {
        self.genericAccountId = genericAccountId
        self.name = name

        provideHeaderViewModel()
    }

    func didReceive(state: WebSocketEngine.State, for chainId: ChainModel.Id) {
        connectionStates[chainId] = state

        provideHeaderViewModel()
        provideAssetViewModels()
    }

    func didReceivePrices(result: Result<[ChainModel.Id: PriceData], Error>) {
        priceResult = result

        let changes: [DataProviderChange<ListModel>] = allChains.values.map { chain in
            let model = createListModel(for: chain)
            return .update(newItem: model)
        }

        connectionListDifference.apply(changes: changes)

        provideHeaderViewModel()
        provideAssetViewModels()
    }

    func didReceiveChainModelChanges(_ changes: [DataProviderChange<ChainModel>]) {
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

        let listChanges: [DataProviderChange<ListModel>] = changes.map { change in
            switch change {
            case let .insert(newItem):
                let model = createListModel(for: newItem)
                return .insert(newItem: model)
            case let .update(newItem):
                let model = createListModel(for: newItem)
                return .update(newItem: model)
            case let .delete(deletedIdentifier):
                return .delete(deletedIdentifier: deletedIdentifier)
            }
        }

        connectionListDifference.apply(changes: listChanges)

        provideHeaderViewModel()
        provideAssetViewModels()
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, chainId: ChainModel.Id) {
        accountResults[chainId] = result

        guard let chainModel = allChains[chainId] else {
            return
        }

        let listModel = createListModel(for: chainModel)
        connectionListDifference.apply(changes: [.update(newItem: listModel)])

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
