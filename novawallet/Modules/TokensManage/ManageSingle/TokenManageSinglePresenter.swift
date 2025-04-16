import Foundation
import Operation_iOS
import Foundation_iOS

final class TokenManageSinglePresenter {
    weak var view: TokenManageSingleViewProtocol?
    let interactor: TokensManageInteractorInputProtocol
    let viewModelFactory: TokensManageViewModelFactoryProtocol
    let networkViewModelFactory: NetworkViewModelFactoryProtocol

    private(set) var chains: [ChainModel.Id: ChainModel] = [:]

    private var token: MultichainToken

    init(
        interactor: TokensManageInteractorInputProtocol,
        token: MultichainToken,
        chains: [ChainModel.Id: ChainModel],
        viewModelFactory: TokensManageViewModelFactoryProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.token = token
        self.chains = chains
        self.viewModelFactory = viewModelFactory
        self.networkViewModelFactory = networkViewModelFactory
        self.localizationManager = localizationManager
    }

    private func updateTokenView() {
        let viewModel = viewModelFactory.createSingleViewModel(from: token, locale: selectedLocale)
        view?.didReceiveTokenManage(viewModel: viewModel)
    }

    private func resetInstancesView() {
        view?.didReceiveNetwork(viewModels: [])
        updateInstancesView()
    }

    private func updateInstancesView() {
        let viewModels: [TokenManageNetworkViewModel] = token.instances.compactMap { instance in
            guard let chain = chains[instance.chainAssetId.chainId] else {
                return nil
            }

            let networkViewModel = networkViewModelFactory.createViewModel(from: chain)

            return TokenManageNetworkViewModel(
                network: networkViewModel,
                chainAssetId: instance.chainAssetId,
                isOn: instance.enabled
            )
        }

        view?.didReceiveNetwork(viewModels: viewModels)
    }

    private func updateToken() {
        let tokenChains = chains.values
            .filter {
                $0.assets.contains {
                    MultichainToken.reserveTokensOf(symbol: $0.symbol).contains(token.symbol)
                }
            }
            .sorted { chain1, chain2 in
                ChainModelCompator.defaultComparator(chain1: chain1, chain2: chain2)
            }

        token = tokenChains.createMultichainToken(for: token.symbol)
    }
}

extension TokenManageSinglePresenter: TokenManageSinglePresenterProtocol {
    func setup() {
        updateTokenView()
        updateInstancesView()

        interactor.setup()
    }

    func performSwitch(for viewModel: TokenManageNetworkViewModel, enabled: Bool) {
        interactor.save(
            chainAssetIds: [viewModel.chainAssetId],
            enabled: enabled,
            allChains: Array(chains.values)
        )
    }
}

extension TokenManageSinglePresenter: TokensManageInteractorOutputProtocol {
    func didReceiveChainModel(changes: [Operation_iOS.DataProviderChange<ChainModel>]) {
        chains = changes.mergeToDict(chains)
        updateToken()
        updateTokenView()
        updateInstancesView()
    }

    func didFailChainSave() {
        updateTokenView()
        resetInstancesView()
    }
}

extension TokenManageSinglePresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateTokenView()
        }
    }
}
