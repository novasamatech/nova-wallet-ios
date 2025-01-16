import Foundation
import Operation_iOS
import Foundation_iOS

final class GovernanceNotificationsPresenter {
    weak var view: GovernanceNotificationsViewProtocol?
    let wireframe: GovernanceNotificationsWireframeProtocol
    let interactor: GovernanceNotificationsInteractorInputProtocol
    let logger: LoggerProtocol

    private let chainList: ListDifferenceCalculator<ChainModel>
    private var settings: GovernanceNotificationsModel
    private var tracks: [ChainModel.Id: [GovernanceTrackInfoLocal]] = [:]

    init(
        initState: GovernanceNotificationsModel,
        interactor: GovernanceNotificationsInteractorInputProtocol,
        wireframe: GovernanceNotificationsWireframeProtocol,
        logger: LoggerProtocol
    ) {
        settings = initState
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger

        chainList = ListDifferenceCalculator(initialItems: []) { chain1, chain2 in
            ChainModelCompator.defaultComparator(chain1: chain1, chain2: chain2)
        }
    }

    private func getTrackIds(for chainId: ChainModel.Id) -> Set<TrackIdLocal>? {
        guard let tracks = tracks[chainId] else {
            return nil
        }

        return Set(tracks.map(\.trackId))
    }

    private func provideViewModels() {
        let viewModels: [GovernanceNotificationsViewModel] = chainList.allItems.compactMap { chain in
            guard let allTrackIds = getTrackIds(for: chain.chainId) else {
                return nil
            }

            let tracks = settings.tracks(for: chain.chainId) ?? allTrackIds
            let selectedTracks = GovernanceNotificationsViewModel.SelectedTracks(
                tracks: tracks,
                totalTracksCount: allTrackIds.count
            )

            return GovernanceNotificationsViewModel(
                identifier: chain.chainId,
                enabled: settings.isNotificationEnabled(for: chain.chainId),
                icon: ImageViewModelFactory.createChainIconOrDefault(from: chain.icon),
                name: chain.name,
                newReferendum: settings.isNewReferendumNotificationEnabled(for: chain.chainId),
                referendumUpdate: settings.isReferendumUpdateNotificationEnabled(for: chain.chainId),
                selectedTracks: selectedTracks
            )
        }

        view?.didReceive(viewModels: viewModels)
    }

    private func provideClearButtonState() {
        let isEnabled = chainList.allItems.contains { settings.isNotificationEnabled(for: $0.chainId) }
        view?.didReceive(isClearActionAvailabe: isEnabled)
    }
}

extension GovernanceNotificationsPresenter: GovernanceNotificationsPresenterProtocol {
    func setup() {
        interactor.setup()
        provideClearButtonState()
    }

    func clear() {
        settings = .empty()

        provideViewModels()
        provideClearButtonState()
    }

    func changeSettings(chainId: ChainModel.Id, isEnabled: Bool) {
        if isEnabled {
            let allTrackIds = getTrackIds(for: chainId) ?? []
            settings = settings
                .enablingNewReferendumNotification(
                    for: allTrackIds,
                    chainId: chainId
                ).enablingReferendumUpdateNotification(
                    for: allTrackIds,
                    chainId: chainId
                )
        } else {
            settings = settings
                .disablingNewReferendumNotification(for: chainId)
                .disablingReferendumUpdateNotification(for: chainId)
        }

        provideViewModels()
        provideClearButtonState()
    }

    func changeSettings(chainId: ChainModel.Id, newReferendum: Bool) {
        let wasEnabled = settings.isNotificationEnabled(for: chainId)

        if newReferendum {
            let tracks = settings.tracks(for: chainId) ?? getTrackIds(for: chainId) ?? []

            settings = settings.enablingNewReferendumNotification(
                for: tracks,
                chainId: chainId
            )
        } else {
            settings = settings.disablingNewReferendumNotification(for: chainId)
        }

        let isEnabled = settings.isNotificationEnabled(for: chainId)

        if wasEnabled != isEnabled {
            provideViewModels()
        }

        provideClearButtonState()
    }

    func changeSettings(chainId: ChainModel.Id, referendumUpdate: Bool) {
        let wasEnabled = settings.isNotificationEnabled(for: chainId)

        if referendumUpdate {
            let tracks = settings.tracks(for: chainId) ?? getTrackIds(for: chainId) ?? []

            settings = settings.enablingReferendumUpdateNotification(
                for: tracks,
                chainId: chainId
            )
        } else {
            settings = settings.disablingReferendumUpdateNotification(for: chainId)
        }

        let isEnabled = settings.isNotificationEnabled(for: chainId)

        if wasEnabled != isEnabled {
            provideViewModels()
        }

        provideClearButtonState()
    }

    func selectTracks(chainId: ChainModel.Id) {
        guard
            let chain = chainList.allItems.first(where: { $0.chainId == chainId }),
            let selectedTracks = settings.tracks(for: chainId) else {
            return
        }

        wireframe.showTracks(
            from: view,
            for: chain,
            selectedTracks: selectedTracks
        ) { [weak self] selectedTracks, _ in
            guard let self = self else {
                return
            }

            if self.settings.isNewReferendumNotificationEnabled(for: chainId) {
                self.settings = self.settings.enablingNewReferendumNotification(
                    for: selectedTracks,
                    chainId: chainId
                )
            }

            if self.settings.isNewReferendumNotificationEnabled(for: chainId) {
                self.settings = self.settings.enablingReferendumUpdateNotification(
                    for: selectedTracks,
                    chainId: chainId
                )
            }

            self.provideViewModels()
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
        provideClearButtonState()
    }

    func didReceiveTracks(_ tracks: [GovernanceTrackInfoLocal], for chain: ChainModel) {
        Logger.shared.debug("Did receive tracks for \(chain.name): \(tracks)")

        self.tracks[chain.chainId] = tracks
        provideViewModels()
    }

    func didReceive(trackFetchError: Error, for _: ChainModel) {
        // this is unexpected error, no need to handle it for now
        logger.error("Did receive tracks error: \(trackFetchError)")
    }
}
