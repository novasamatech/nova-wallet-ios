import Foundation
import Foundation_iOS

final class GovernanceUnavailableTracksPresenter {
    weak var view: GovernanceUnavailableTracksViewProtocol?
    let wireframe: GovernanceUnavailableTracksWireframeProtocol
    weak var delegate: GovernanceUnavailableTracksDelegate?
    let votedTracks: [GovernanceTrackInfoLocal]
    let delegatedTracks: [GovernanceTrackInfoLocal]
    let chain: ChainModel
    let trackViewModelFactory: GovernanceTrackViewModelFactoryProtocol

    init(
        wireframe: GovernanceUnavailableTracksWireframeProtocol,
        delegate: GovernanceUnavailableTracksDelegate,
        votedTracks: [GovernanceTrackInfoLocal],
        delegatedTracks: [GovernanceTrackInfoLocal],
        chain: ChainModel,
        trackViewModelFactory: GovernanceTrackViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.delegate = delegate
        self.votedTracks = votedTracks
        self.delegatedTracks = delegatedTracks
        self.chain = chain
        self.trackViewModelFactory = trackViewModelFactory
        self.localizationManager = localizationManager
    }

    private func updateView() {
        let votedTrackViewModels = trackViewModelFactory.createViewModels(
            from: votedTracks,
            chain: chain,
            locale: selectedLocale
        )

        let delegatedTrackViewModels = trackViewModelFactory.createViewModels(
            from: delegatedTracks,
            chain: chain,
            locale: selectedLocale
        )

        view?.didReceive(
            votedTracks: votedTrackViewModels,
            delegatedTracks: delegatedTrackViewModels
        )
    }
}

extension GovernanceUnavailableTracksPresenter: GovernanceUnavailableTracksPresenterProtocol {
    func setup() {
        updateView()
    }

    func removeVotes() {
        wireframe.complete(on: view) {
            self.delegate?.unavailableTracksDidDecideRemoveVotes()
        }
    }
}

extension GovernanceUnavailableTracksPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
