import Foundation
import RobinHood
import SoraFoundation

final class GovernanceNotificationsPresenter {
    weak var view: GovernanceNotificationsViewProtocol?
    let wireframe: GovernanceNotificationsWireframeProtocol
    let interactor: GovernanceNotificationsInteractorInputProtocol
    private let chainList: ListDifferenceCalculator<ChainModel>
    private var settings: [ChainModel.Id: GovernanceNotificationsModel]

    init(
        settings: [ChainModel.Id: GovernanceNotificationsModel] = [:],
        interactor: GovernanceNotificationsInteractorInputProtocol,
        wireframe: GovernanceNotificationsWireframeProtocol
    ) {
        self.settings = settings
        self.interactor = interactor
        self.wireframe = wireframe

        chainList = ListDifferenceCalculator(initialItems: []) { chain1, chain2 in
            ChainModelCompator.defaultComparator(chain1: chain1, chain2: chain2)
        }
    }

    private func provideViewModels() {
        let viewModel = chainList.allItems.map {
            if let chainSettings = settings[$0.identifier] {
                return GovernanceNotificationsModel(
                    identifier: $0.identifier,
                    enabled: chainSettings.enabled,
                    icon: RemoteImageViewModel(url: $0.icon),
                    name: $0.name,
                    newReferendum: chainSettings.newReferendum,
                    referendumUpdate: chainSettings.referendumUpdate,
                    delegateHasVoted: chainSettings.delegateHasVoted,
                    tracks: chainSettings.tracks
                )
            } else {
                let newModel = GovernanceNotificationsModel(
                    identifier: $0.identifier,
                    enabled: false,
                    icon: RemoteImageViewModel(url: $0.icon),
                    name: $0.name,
                    newReferendum: true,
                    referendumUpdate: true,
                    delegateHasVoted: true,
                    tracks: .all
                )
                settings[$0.identifier] = newModel
                return newModel
            }
        }

        view?.didReceive(viewModels: viewModel)
    }

    private func provideClearButtonState() {
        let isEnabled = settings.contains(where: { $0.value.enabled })
        view?.didReceive(isClearActionAvailabe: isEnabled)
    }

    private func disableChainNotificationsIfNeeded(network: ChainModel.Id) {
        if settings[network]?.allNotificationsIsOff == true {
            changeSettings(network: network, isEnabled: false)
            settings[network].map {
                self.view?.didReceiveUpdates(for: $0)
            }
        }
    }
}

extension GovernanceNotificationsPresenter: GovernanceNotificationsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func clear() {
        settings.removeAll()
        provideViewModels()
        provideClearButtonState()
    }

    func changeSettings(network: ChainModel.Id, isEnabled: Bool) {
        settings[network]?.enabled = isEnabled
        provideClearButtonState()
    }

    func changeSettings(network: ChainModel.Id, newReferendum: Bool) {
        settings[network]?.newReferendum = newReferendum
        disableChainNotificationsIfNeeded(network: network)
    }

    func changeSettings(network: ChainModel.Id, referendumUpdate: Bool) {
        settings[network]?.referendumUpdate = referendumUpdate
        disableChainNotificationsIfNeeded(network: network)
    }

    func changeSettings(network: ChainModel.Id, delegateHasVoted: Bool) {
        settings[network]?.delegateHasVoted = delegateHasVoted
        disableChainNotificationsIfNeeded(network: network)
    }

    func selectTracks(network: ChainModel.Id) {
        guard let chain = chainList.allItems.first(where: { $0.identifier == network }) else {
            return
        }

        let selectedTracks = settings[chain.identifier]?.selectedTracks
        wireframe.showTracks(from: view, for: chain, selectedTracks: selectedTracks) { [weak self] selectedTracks, count in
            self?.settings[chain.identifier]?.set(selectedTracks: selectedTracks, count: count)
            self?.provideViewModels()
        }
    }

    func proceed() {
        wireframe.complete(settings: settings)
    }
}

extension GovernanceNotificationsPresenter: GovernanceNotificationsInteractorOutputProtocol {
    func didReceiveChainModel(changes: [DataProviderChange<ChainModel>]) {
        chainList.apply(changes: changes)
        provideViewModels()
    }
}
