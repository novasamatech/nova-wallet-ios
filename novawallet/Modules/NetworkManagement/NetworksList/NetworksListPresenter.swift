import Foundation
import Operation_iOS
import Foundation_iOS

final class NetworksListPresenter {
    weak var view: NetworksListViewProtocol?
    let wireframe: NetworksListWireframeProtocol
    let interactor: NetworksListInteractorInputProtocol

    private var chains: [ChainModel.Id: ChainModel] = [:]
    private var connectionStates: [ChainModel.Id: ConnectionState] = [:]
    private var chainIndexes: [ChainModel.Id: Int] = [:]

    private var searchQuery: String?
    private var selectedNetworksType: NetworksType = .default
    private var sortedChains: SortedChains?

    private let viewModelFactory: NetworksListViewModelFactory

    init(
        interactor: NetworksListInteractorInputProtocol,
        wireframe: NetworksListWireframeProtocol,
        viewModelFactory: NetworksListViewModelFactory
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
    }
}

// MARK: NetworksListPresenterProtocol

extension NetworksListPresenter: NetworksListPresenterProtocol {
    func selectChain(at index: Int) {
        guard let sortedChains else {
            return
        }

        let chainModel = switch selectedNetworksType {
        case .added:
            searched(from: sortedChains.addedChains)[index]
        case .default:
            searched(from: sortedChains.defaultChains)[index]
        }

        wireframe.showNetworkDetails(from: view, with: chainModel)
    }

    func select(segment: NetworksType?) {
        guard let segment else {
            return
        }

        selectedNetworksType = segment
        indexChains()
        provideViewModels()
    }

    func search(with query: String?) {
        searchQuery = query

        indexChains()
        provideViewModels()
    }

    func setup() {
        interactor.provideChains()
    }

    func addNetwork() {
        wireframe.showAddNetwork(from: view)
    }

    func integrateOwnNetwork() {
        wireframe.showIntegrateOwnNetwork(from: view)
    }

    func closeBanner() {
        interactor.setIntegrationBannerSeen()
        provideViewModels()
    }
}

// MARK: NetworksListInteractorOutputProtocol

extension NetworksListPresenter: NetworksListInteractorOutputProtocol {
    func didReceiveChains(changes: [DataProviderChange<ChainModel>]) {
        chains = changes.mergeToDict(chains)
        sortedChains = sorted(chains: chains)

        indexChains()

        provideViewModels()
    }

    func didReceive(
        connectionState: ConnectionState,
        for chainId: ChainModel.Id
    ) {
        connectionStates[chainId] = connectionState
        provideNetworkViewModel(for: chainId)
    }
}

// MARK: Private

private extension NetworksListPresenter {
    func provideViewModels() {
        guard let sortedChains else { return }

        let viewModel = switch selectedNetworksType {
        case .default:
            viewModelFactory.createDefaultViewModel(
                for: searched(from: sortedChains.defaultChains),
                indexes: chainIndexes,
                with: connectionStates
            )
        case .added:
            viewModelFactory.createAddedViewModel(
                for: searched(from: sortedChains.addedChains),
                indexes: chainIndexes,
                with: connectionStates
            )
        }

        view?.update(with: viewModel)
    }

    func provideNetworkViewModel(for chainId: ChainModel.Id) {
        guard
            let chain = chains[chainId],
            chainIndexes[chainId] != nil
        else {
            return
        }

        let viewModel = viewModelFactory.createDefaultViewModel(
            for: [chain],
            indexes: chainIndexes,
            with: connectionStates
        )

        view?.updateNetworks(with: viewModel)
    }

    func searched(from chains: [ChainModel]) -> [ChainModel] {
        let searchedChains: [ChainModel] = if let searchQuery, !searchQuery.isEmpty {
            chains.filter { $0.name.lowercased().contains(substring: searchQuery.lowercased()) }
        } else {
            chains
        }

        return searchedChains
    }

    func sorted(chains: [ChainModel.Id: ChainModel]) -> SortedChains {
        var defaultChains: [ChainModel] = []
        var addedChains: [ChainModel] = []

        chains.forEach { chain in
            if chain.value.source == .remote {
                defaultChains.append(chain.value)
            } else {
                addedChains.append(chain.value)
            }
        }

        defaultChains.sort { ChainModelCompator.defaultComparator(chain1: $0, chain2: $1) }
        addedChains.sort { ChainModelCompator.defaultComparator(chain1: $0, chain2: $1) }

        return SortedChains(
            defaultChains: defaultChains,
            addedChains: addedChains
        )
    }

    func indexChains() {
        guard let sortedChains else {
            return
        }

        chainIndexes = [:]

        let chainsToIndex = switch selectedNetworksType {
        case .default:
            searched(from: sortedChains.defaultChains)
        case .added:
            searched(from: sortedChains.addedChains)
        }

        chainsToIndex.enumerated().forEach { index, chain in
            chainIndexes[chain.chainId] = index
        }
    }
}

extension NetworksListPresenter {
    enum ConnectionState {
        case notConnected
        case connecting
        case connected
    }

    enum NetworksType: Int {
        case `default` = 0
        case added = 1
    }

    struct SortedChains {
        let defaultChains: [ChainModel]
        let addedChains: [ChainModel]
    }
}
