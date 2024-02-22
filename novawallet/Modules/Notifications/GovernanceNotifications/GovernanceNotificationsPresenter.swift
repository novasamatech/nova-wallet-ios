import Foundation
import RobinHood
import SoraFoundation

final class GovernanceNotificationsPresenter {
    weak var view: GovernanceNotificationsViewProtocol?
    let wireframe: GovernanceNotificationsWireframeProtocol
    let interactor: GovernanceNotificationsInteractorInputProtocol
    private let chainList: ListDifferenceCalculator<ChainModel>
    private var settings: [ChainModel.Id: GovernanceNotificationsModel] = [:]
    private var initState: GovernanceNotificationsInitModel?

    init(
        initState: GovernanceNotificationsInitModel?,
        interactor: GovernanceNotificationsInteractorInputProtocol,
        wireframe: GovernanceNotificationsWireframeProtocol
    ) {
        self.initState = initState
        self.interactor = interactor
        self.wireframe = wireframe

        chainList = ListDifferenceCalculator(initialItems: []) { chain1, chain2 in
            ChainModelCompator.defaultComparator(chain1: chain1, chain2: chain2)
        }
    }

    private func provideViewModels() {
        let viewModels = chainList.allItems.map {
            if let chainSettings = settings[$0.identifier] {
                return GovernanceNotificationsModel(
                    identifier: $0.identifier,
                    enabled: chainSettings.enabled,
                    icon: RemoteImageViewModel(url: $0.icon),
                    name: $0.name,
                    newReferendum: chainSettings.newReferendum,
                    referendumUpdate: chainSettings.referendumUpdate,
                    tracks: chainSettings.tracks
                )
            } else {
                return GovernanceNotificationsModel(
                    identifier: $0.identifier,
                    enabled: false,
                    icon: RemoteImageViewModel(url: $0.icon),
                    name: $0.name,
                    newReferendum: true,
                    referendumUpdate: true,
                    tracks: .all
                )
            }
        }

        settings = viewModels.reduce(into: settings) {
            $0[$1.identifier] = $1
        }

        view?.didReceive(viewModels: viewModels)
    }

    private func provideClearButtonState() {
        let isEnabled = settings.contains(where: { $0.value.enabled })
        view?.didReceive(isClearActionAvailabe: isEnabled)
    }

    private func disableChainNotificationsIfNeeded(chainId: ChainModel.Id) {
        guard var chainSettings = settings[chainId], chainSettings.allNotificationsIsOff else {
            return
        }

        chainSettings.enabled = false
        settings[chainId] = chainSettings
        view?.didReceiveUpdates(for: chainSettings)
    }

    private func initializeIfNeeded() {
        guard let initState = initState else {
            return
        }

        settings = chainList.allItems.reduce(into: settings) { result, chain in
            let newReferendum = initState.newReferendum[chain.chainId] != nil
            let referendumUpdate = initState.referendumUpdate[chain.chainId] != nil
            let enabled = newReferendum || referendumUpdate
            let tracks: GovernanceNotificationsModel.SelectedTracks = initState.tracks(for: chain.chainId).map {
                switch $0 {
                case .all:
                    return .all
                case let .concrete(values):
                    return .concrete(values, count: nil)
                }
            } ?? .all

            result[chain.chainId] = GovernanceNotificationsModel(
                identifier: chain.identifier,
                enabled: enabled,
                icon: RemoteImageViewModel(url: chain.icon),
                name: chain.name,
                newReferendum: enabled ? newReferendum : true,
                referendumUpdate: enabled ? referendumUpdate : true,
                tracks: tracks
            )
        }

        self.initState = nil
    }
}

extension GovernanceNotificationsPresenter: GovernanceNotificationsPresenterProtocol {
    func setup() {
        interactor.setup()
        provideClearButtonState()
    }

    func clear() {
        settings.removeAll()
        provideViewModels()
        provideClearButtonState()
    }

    func changeSettings(chainId: ChainModel.Id, isEnabled: Bool) {
        settings[chainId]?.enabled = isEnabled
        provideClearButtonState()
    }

    func changeSettings(chainId: ChainModel.Id, newReferendum: Bool) {
        settings[chainId]?.newReferendum = newReferendum
        disableChainNotificationsIfNeeded(chainId: chainId)
        provideClearButtonState()
    }

    func changeSettings(chainId: ChainModel.Id, referendumUpdate: Bool) {
        settings[chainId]?.referendumUpdate = referendumUpdate
        disableChainNotificationsIfNeeded(chainId: chainId)
        provideClearButtonState()
    }

    func selectTracks(chainId: ChainModel.Id) {
        guard let chain = chainList.allItems.first(where: { $0.identifier == chainId }) else {
            return
        }

        let selectedTracks = settings[chain.identifier]?.selectedTracks
        wireframe.showTracks(
            from: view,
            for: chain,
            selectedTracks: selectedTracks
        ) { [weak self] selectedTracks, count in
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
        initializeIfNeeded()
        provideViewModels()
        provideClearButtonState()
    }
}
