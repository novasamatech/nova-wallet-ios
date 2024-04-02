import Foundation
import SoraFoundation

class SelectTracksPresenter: SelectTracksPresenterProtocol {
    weak var selectTracksView: SelectTracksViewProtocol?
    let selectTracksInteractor: SelectTracksInteractorInputProtocol
    let selectTracksWireframe: SelectTracksWireframeProtocol

    let chain: ChainModel
    let logger: LoggerProtocol

    private(set) var tracks: [GovernanceTrackInfoLocal]?
    var availableTrackIds: Set<TrackIdLocal>?
    var selectedTracks: Set<ReferendumTrackType>?

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
                title: type.title(for: selectedLocale)?.uppercased() ?? "",
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

        selectTracksView?.didReceiveTracks(viewModel: viewModel)
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

        selectedTracks = availableTrackTypes.intersection(Set(group.trackTypes))

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
        if selectedTracks?.contains(track.type) != true {
            selectedTracks?.insert(track.type)
        } else {
            selectedTracks?.remove(track.type)
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
