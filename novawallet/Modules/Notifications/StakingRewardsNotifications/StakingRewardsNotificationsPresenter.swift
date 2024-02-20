import Foundation
import RobinHood

final class StakingRewardsNotificationsPresenter {
    weak var view: StakingRewardsNotificationsViewProtocol?
    let wireframe: StakingRewardsNotificationsWireframeProtocol
    let interactor: StakingRewardsNotificationsInteractorInputProtocol
    private let chainList: ListDifferenceCalculator<ChainModel>
    private var selectedChains: Set<ChainModel.Id>

    init(
        selectedChains: Set<ChainModel.Id> = .init(),
        interactor: StakingRewardsNotificationsInteractorInputProtocol,
        wireframe: StakingRewardsNotificationsWireframeProtocol
    ) {
        self.selectedChains = selectedChains
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
                enabled: selectedChains.contains($0.chainId)
            )
        }

        view?.didReceive(viewModels: viewModels)
    }

    private func provideClearButtonState() {
        let enabled = !selectedChains.isEmpty
        view?.didReceive(isClearActionAvailabe: enabled)
    }
}

extension StakingRewardsNotificationsPresenter: StakingRewardsNotificationsPresenterProtocol {
    func setup() {
        interactor.setup()
        provideClearButtonState()
    }

    func clear() {
        selectedChains.removeAll()
        provideViewModels()
        provideClearButtonState()
    }

    func changeSettings(network: String, isEnabled: Bool) {
        if isEnabled {
            selectedChains.insert(network)
        } else {
            selectedChains.remove(network)
        }
        provideClearButtonState()
    }

    func proceed() {
        wireframe.complete(
            selectedChains: selectedChains,
            totalChainsCount: chainList.allItems.count
        )
    }
}

extension StakingRewardsNotificationsPresenter: StakingRewardsNotificationsInteractorOutputProtocol {
    func didReceiveChainModel(changes: [DataProviderChange<ChainModel>]) {
        chainList.apply(changes: changes)
        provideViewModels()
    }
}
