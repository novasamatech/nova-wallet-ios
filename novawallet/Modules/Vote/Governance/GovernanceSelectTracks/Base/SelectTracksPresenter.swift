import Foundation
import Foundation_iOS

class SelectTracksPresenter: SelectTracksPresenterProtocol {
    weak var selectTracksView: SelectTracksViewProtocol?
    let selectTracksInteractor: SelectTracksInteractorInputProtocol
    let selectTracksWireframe: SelectTracksWireframeProtocol

    let chain: ChainModel
    let logger: LoggerProtocol

    private(set) var tracks: [GovernanceTrackInfoLocal]?
    var availableTrackIds: Set<TrackIdLocal>?
    var selectedTrackIds: Set<TrackIdLocal>?

    init(
        interactor: SelectTracksInteractorInputProtocol,
        wireframe: SelectTracksWireframeProtocol,
        chain: ChainModel,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        selectTracksInteractor = interactor
        selectTracksWireframe = wireframe
        self.chain = chain
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func getAvailableTrackTypes() -> Set<String>? {
        guard let tracks = tracks, let availableTrackIds = availableTrackIds else {
            return nil
        }

        let availableTracks = tracks.filter { availableTrackIds.contains($0.trackId) }
        return Set(availableTracks.map(\.name))
    }

    private func createTrackViewModels(
        from availableTracks: [GovernanceTrackInfoLocal],
        selectedTrackIds: Set<TrackIdLocal>
    ) -> [GovernanceSelectTrackViewModel.Track] {
        availableTracks.map { track in
            let selected = selectedTrackIds.contains(track.trackId)

            let viewModel = ReferendumInfoView.Track(
                title: ReferendumTrackType.title(for: track.name, locale: selectedLocale).uppercased(),
                icon: ReferendumTrackType.imageViewModel(for: track.name, chain: chain)
            )

            return GovernanceSelectTrackViewModel.Track(
                trackId: track.trackId,
                viewModel: .init(underlyingViewModel: viewModel, selectable: selected)
            )
        }
    }

    private func createGroupViewModels(
        from availableTrackTypes: Set<String>
    ) -> [GovernanceSelectTrackViewModel.Group] {
        let selectAllViewModel = GovernanceSelectTrackViewModel.Group.all(
            title: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonSelectAll()
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
            let tracks,
            let selectedTrackIds else {
            return
        }

        let availableTracks = tracks.filter { availableTrackIds.contains($0.trackId) }

        let availableTracksViewModel = createTrackViewModels(
            from: availableTracks,
            selectedTrackIds: selectedTrackIds
        )

        let trackGroupsViewModel = createGroupViewModels(from: availableTrackTypes)

        let viewModel = GovernanceSelectTrackViewModel(
            trackGroups: trackGroupsViewModel,
            availableTracks: availableTracksViewModel
        )

        selectTracksView?.didReceiveTracks(viewModel: viewModel)
    }

    private func performSelectAll() {
        guard let availableTrackIds else {
            return
        }

        selectedTrackIds = availableTrackIds

        updateTracksView()
    }

    private func performSelect(group: ReferendumTrackGroup) {
        guard let tracks, let availableTrackTypes = getAvailableTrackTypes() else {
            return
        }

        let selectedTypes = availableTrackTypes.intersection(Set(group.trackTypes))
        selectedTrackIds = Set(tracks.compactMap { selectedTypes.contains($0.name) ? $0.trackId : nil })

        updateTracksView()
    }

    // MARK: - SelectTracksPresenterProtocol

    func setup() {
        selectTracksInteractor.setup()
    }

    func select(group: GovernanceSelectTrackViewModel.Group) {
        switch group {
        case .all:
            performSelectAll()
        case let .concrete(trackGroup, _):
            performSelect(group: trackGroup)
        }
    }

    func toggleTrackSelection(track: GovernanceSelectTrackViewModel.Track) {
        if selectedTrackIds?.contains(track.trackId) != true {
            selectedTrackIds?.insert(track.trackId)
        } else {
            selectedTrackIds?.remove(track.trackId)
        }

        updateTracksView()
    }

    func proceed() {
        fatalError("Must be implemented by child class")
    }
}

extension SelectTracksPresenter: SelectTracksInteractorOutputProtocol {
    func didReceiveTracks(_ tracks: [GovernanceTrackInfoLocal]) {
        self.tracks = tracks

        setupAvailableTracks()
        setupSelectedTracks()
        updateView()
    }

    func didReceiveError(selectTracksError error: SelectTracksInteractorError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .tracksFetchFailed:
            selectTracksWireframe.presentRequestStatus(on: selectTracksView, locale: nil) { [weak self] in
                self?.selectTracksInteractor.retryTracksFetch()
            }
        }
    }
}

extension SelectTracksPresenter: Localizable {
    func applyLocalization() {
        if let view = selectTracksView, view.isSetup {
            updateView()
        }
    }
}
