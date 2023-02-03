import Foundation
import SoraFoundation

final class GovernanceSelectTracksPresenter {
    weak var view: GovernanceSelectTracksViewProtocol?
    let wireframe: GovernanceSelectTracksWireframeProtocol
    let interactor: GovernanceSelectTracksInteractorInputProtocol
    let chain: ChainModel
    let logger: LoggerProtocol

    private var tracks: [GovernanceTrackInfoLocal]?
    private var votingResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    private var availableTrackIds: Set<UInt16>?
    private var selectedTracks: Set<ReferendumTrackType>?

    init(
        interactor: GovernanceSelectTracksInteractorInputProtocol,
        wireframe: GovernanceSelectTracksWireframeProtocol,
        chain: ChainModel,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func getAvailableTrackTypes() -> Set<ReferendumTrackType>? {
        guard let tracks = tracks, let availableTrackIds = availableTrackIds else {
            return nil
        }

        let availableTracks = tracks.filter { availableTrackIds.contains($0.trackId) }
        return Set(availableTracks.compactMap { ReferendumTrackType(rawValue: $0.name) })
    }

    private func createTrackViewModels(
        from availableTracks: [GovernanceTrackInfoLocal],
        selectedTracks: Set<ReferendumTrackType>
    ) -> [GovernanceSelectTrackViewModel.Track] {
        availableTracks.compactMap { track in
            guard let type = ReferendumTrackType(rawValue: track.name) else {
                return nil
            }

            let selected = selectedTracks.contains(type)

            let viewModel = ReferendumInfoView.Track(
                title: type.title(for: selectedLocale) ?? "",
                icon: type.imageViewModel(for: chain)
            )

            return GovernanceSelectTrackViewModel.Track(
                type: type,
                viewModel: .init(underlyingViewModel: viewModel, selectable: selected)
            )
        }
    }

    private func createGroupViewModels(
        from availableTrackTypes: Set<ReferendumTrackType>
    ) -> [GovernanceSelectTrackViewModel.Group] {
        let allTrackGroups = ReferendumTrackGroup.groupsByPriority()

        return allTrackGroups.filter { group in
            !Set(group.trackTypes).isDisjoint(with: availableTrackTypes)
        }.map { trackGroup in
            let title = trackGroup.title(for: selectedLocale)

            return .concrete(trackGroup: trackGroup, title: title)
        }
    }

    func setupAvailableTracks() {
        fatalError("Must be implemented by child class")
    }

    func setupSelectedTracks() {
        fatalError("Must be implemented by child class")
    }

    func updateView() {
        updateTracksView()
    }

    func updateTracksView() {
        guard
            let availableTrackIds = availableTrackIds,
            let availableTrackTypes = getAvailableTrackTypes(),
            let tracks = tracks,
            let selectedTracks = selectedTracks else {
            return
        }

        let availableTracks = tracks.filter { availableTrackIds.contains($0.trackId) }

        let availableTracksViewModel = createTrackViewModels(
            from: availableTracks,
            selectedTracks: selectedTracks
        )

        let trackGroupsViewModel = createGroupViewModels(from: availableTrackTypes)

        let viewModel = GovernanceSelectTrackViewModel(
            trackGroups: trackGroupsViewModel,
            availableTracks: availableTracksViewModel
        )

        view?.didReceiveTracks(viewModel: viewModel)
    }

    private func performSelectAll() {
        guard let availableTrackTypes = getAvailableTrackTypes() else {
            return
        }

        selectedTracks?.formUnion(availableTrackTypes)

        updateTracksView()
    }

    private func performSelect(group: ReferendumTrackGroup) {
        guard let availableTrackTypes = getAvailableTrackTypes() else {
            return
        }

        selectedTracks?.formUnion(availableTrackTypes.intersection(Set(group.trackTypes)))

        updateTracksView()
    }
}

extension GovernanceSelectTracksPresenter: GovernanceSelectTracksPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func select(track: GovernanceSelectTrackViewModel.Track) {
        selectedTracks?.insert(track.type)

        updateTracksView()
    }

    func select(group: GovernanceSelectTrackViewModel.Group) {
        switch group {
        case .all:
            performSelectAll()
        case let .concrete(trackGroup, _):
            performSelect(group: trackGroup)
        }
    }

    func proceed() {}
}

extension GovernanceSelectTracksPresenter: GovernanceSelectTracksInteractorOutputProtocol {
    func didReceiveTracks(_ tracks: [GovernanceTrackInfoLocal]) {
        self.tracks = tracks

        setupAvailableTracks()
        setupSelectedTracks()
        updateView()
    }

    func didReceiveVotingResult(_ result: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>) {
        votingResult = result

        setupAvailableTracks()
        setupSelectedTracks()
        updateView()
    }

    func didReceiveError(_ error: GovernanceSelectTracksInteractorError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .tracksFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: nil) { [weak self] in
                self?.interactor.retryTracksFetch()
            }
        case .votesSubsctiptionFailed:
            wireframe.presentRequestStatus(on: view, locale: nil) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        }
    }
}

extension GovernanceSelectTracksPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
