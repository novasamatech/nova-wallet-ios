import Foundation
import SoraFoundation
import RobinHood

final class CommonDelegationTracksPresenter {
    weak var view: CommonDelegationTracksViewProtocol?
    let viewModelFactory: GovernanceTrackViewModelFactoryProtocol
    let stringFactory: ReferendumDisplayStringFactoryProtocol
    let tracks: [TrackVote]
    let chain: ChainModel

    init(
        tracks: [TrackVote],
        chain: ChainModel,
        viewModelFactory: GovernanceTrackViewModelFactoryProtocol,
        stringFactory: ReferendumDisplayStringFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.tracks = tracks
        self.chain = chain
        self.viewModelFactory = viewModelFactory
        self.stringFactory = stringFactory
        self.localizationManager = localizationManager
    }

    private func mapTrackToViewModel(trackVote: TrackVote) -> TrackTableViewCell.Model {
        let trackViewModel = viewModelFactory.createViewModel(
            from: trackVote.track,
            chain: chain,
            locale: selectedLocale
        )
        guard let vote = trackVote.vote else {
            return .init(track: trackViewModel, details: nil)
        }

        let votes = vote.conviction.votes(for: vote.balance) ?? 0
        let votesString = stringFactory.createVotes(
            from: votes,
            chain: chain,
            locale: selectedLocale
        )

        let voteDetails = stringFactory.createVotesDetails(
            from: vote.balance,
            conviction: vote.conviction.decimalValue,
            chain: chain,
            locale: selectedLocale
        )
        let trackDetails = MultiValueView.Model(
            topValue: votesString ?? "",
            bottomValue: voteDetails
        )

        return .init(
            track: trackViewModel,
            details: trackDetails
        )
    }

    private func updateView() {
        let viewModels = tracks.map(mapTrackToViewModel)
        view?.didReceive(tracks: viewModels)
    }
}

extension CommonDelegationTracksPresenter: CommonDelegationTracksPresenterProtocol {
    func setup() {
        updateView()
    }
}

extension CommonDelegationTracksPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
