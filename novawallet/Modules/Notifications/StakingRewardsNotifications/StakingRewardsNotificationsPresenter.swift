import Foundation
import RobinHood

final class StakingRewardsNotificationsPresenter {
    weak var view: StakingRewardsNotificationsViewProtocol?
    let wireframe: StakingRewardsNotificationsWireframeProtocol
    let interactor: StakingRewardsNotificationsInteractorInputProtocol
    private let chainList: ListDifferenceCalculator<ChainModel>
    private let initialState: Web3Alert.Selection<Set<ChainModel.Id>>?
    private var selectedChains: Set<ChainModel.Id>?

    init(
        initialState: Web3Alert.Selection<Set<ChainModel.Id>>?,
        interactor: StakingRewardsNotificationsInteractorInputProtocol,
        wireframe: StakingRewardsNotificationsWireframeProtocol
    ) {
        self.initialState = initialState
        self.interactor = interactor
        self.wireframe = wireframe

        chainList = ListDifferenceCalculator(initialItems: []) { chain1, chain2 in
            ChainModelCompator.defaultComparator(chain1: chain1, chain2: chain2)
        }
    }

    private func provideViewModels() {
        let viewModels = chainList.allItems.map {
            StakingRewardsNotificationsViewModel(
                identifier: $0.identifier,
                icon: RemoteImageViewModel(url: $0.icon),
                name: $0.name,
                enabled: selectedChains?.contains($0.identifier) == true
            )
        }

        view?.didReceive(viewModels: viewModels)
    }

    private func provideClearButtonState() {
        let enabled = selectedChains.map { !$0.isEmpty } ?? false
        view?.didReceive(isClearActionAvailabe: enabled)
    }
}

extension StakingRewardsNotificationsPresenter: StakingRewardsNotificationsPresenterProtocol {
    func setup() {
        interactor.setup()
        provideClearButtonState()
    }

    func clear() {
        selectedChains = .init()
        provideViewModels()
        provideClearButtonState()
    }

    func changeSettings(chainId: ChainModel.Id, isEnabled: Bool) {
        if isEnabled {
            selectedChains?.insert(chainId)
        } else {
            selectedChains?.remove(chainId)
        }
        provideClearButtonState()
    }

    func proceed() {
        if let selectedChains = selectedChains {
            let selectedAll = selectedChains.count == chainList.allItems.count
            wireframe.complete(selectedChains: selectedAll ? .all : .concrete(Set(selectedChains)))
        }
    }
}

extension StakingRewardsNotificationsPresenter: StakingRewardsNotificationsInteractorOutputProtocol {
    func didReceiveChainModel(changes: [DataProviderChange<ChainModel>]) {
        chainList.apply(changes: changes)
        if selectedChains == nil {
            switch initialState {
            case .all:
                selectedChains = Set(chainList.allItems.map(\.identifier))
            case let .concrete(chains):
                selectedChains = Set(chainList.allItems.filter { chains.contains($0.identifier) }.map(\.identifier))
            case .none:
                selectedChains = .init()
            }
            provideClearButtonState()
        }
        provideViewModels()
    }
}
