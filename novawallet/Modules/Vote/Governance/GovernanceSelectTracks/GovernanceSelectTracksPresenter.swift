import Foundation
import SoraFoundation

class GovernanceSelectTracksPresenter {
    weak var baseView: GovernanceSelectTracksViewProtocol?
    let baseWireframe: GovernanceSelectTracksWireframeProtocol
    let interactor: GovernanceSelectTracksInteractorInputProtocol
    let chain: ChainModel
    let logger: LoggerProtocol

    private(set) var tracks: [GovernanceTrackInfoLocal]?
    private(set) var votingResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    var availableTrackIds: Set<TrackIdLocal>?
    var selectedTracks: Set<ReferendumTrackType>?

    init(
        interactor: GovernanceSelectTracksInteractorInputProtocol,
        baseWireframe: GovernanceSelectTracksWireframeProtocol,
        chain: ChainModel,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.baseWireframe = baseWireframe
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
        let selectAllViewModel = GovernanceSelectTrackViewModel.Group.all(
            title: R.string.localizable.commonSelectAll(
                preferredLanguages: selectedLocale.rLanguages
            )
        )

        let allTrackGroups = ReferendumTrackGroup.groupsByPriority()

        let concreteViewModels = allTrackGroups.filter { group in
            !Set(group.trackTypes).isDisjoint(with: availableTrackTypes)
        }.map { trackGroup in
            let title = trackGroup.title(for: selectedLocale)

            return GovernanceSelectTrackViewModel.Group.concrete(trackGroup: trackGroup, title: title)
        }

        return [selectAllViewModel] + concreteViewModels
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

        baseView?.didReceiveTracks(viewModel: viewModel)
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

    func toggleTrackSelection(track: GovernanceSelectTrackViewModel.Track) {
        guard let selectedTracks = selectedTracks else {
            return
        }

        if !selectedTracks.contains(track.type) {
            selectedTracks.insert(track.type)
        } else {
            selectedTracks.remove(track.type)
        }

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

    func proceed() {
        guard let selectedTrackTypes = selectedTracks, let allTracks = tracks else {
            return
        }

        let selectedTracks = allTracks.filter { track in
            guard let trackType = ReferendumTrackType(rawValue: track.name) else {
                return false
            }

            return selectedTrackTypes.contains(trackType)
        }

        baseWireframe.proceed(from: baseView, tracks: selectedTracks)
    }
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
            baseWireframe.presentRequestStatus(on: baseView, locale: nil) { [weak self] in
                self?.interactor.retryTracksFetch()
            }
        case .votesSubsctiptionFailed:
            baseWireframe.presentRequestStatus(on: baseView, locale: nil) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        }
    }
}

extension GovernanceSelectTracksPresenter: Localizable {
    func applyLocalization() {
        if let view = baseView, view.isSetup {
            updateView()
        }
    }
}
