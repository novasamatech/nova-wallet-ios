import Foundation
import Foundation_iOS
import Operation_iOS

final class CommonDelegationTracksPresenter {
    weak var view: CommonDelegationTracksViewProtocol?
    let viewModelFactory: GovernanceTrackViewModelFactoryProtocol
    let stringFactory: ReferendumDisplayStringFactoryProtocol
    let tracks: [GovernanceTrackInfoLocal]
    let delegations: [TrackIdLocal: ReferendumDelegatingLocal]
    let chain: ChainModel

    init(
        tracks: [GovernanceTrackInfoLocal],
        delegations: [TrackIdLocal: ReferendumDelegatingLocal],
        chain: ChainModel,
        viewModelFactory: GovernanceTrackViewModelFactoryProtocol,
        stringFactory: ReferendumDisplayStringFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.tracks = tracks
        self.delegations = delegations
        self.chain = chain
        self.viewModelFactory = viewModelFactory
        self.stringFactory = stringFactory
        self.localizationManager = localizationManager
    }

    private func mapTrackToViewModel(
        track: GovernanceTrackInfoLocal,
        delegation: ReferendumDelegatingLocal?
    ) -> TrackTableViewCell.Model {
        let trackViewModel = viewModelFactory.createViewModel(
            from: track,
            chain: chain,
            locale: selectedLocale
        )
        guard let delegation = delegation else {
            return .init(track: trackViewModel, details: nil)
        }

        let votes = delegation.conviction.votes(for: delegation.balance) ?? 0
        let votesString = stringFactory.createVotes(
            from: votes,
            chain: chain,
            locale: selectedLocale
        )

        let voteDetails = stringFactory.createVotesDetails(
            from: delegation.balance,
            conviction: delegation.conviction.decimalValue,
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
        let viewModels = tracks.map { mapTrackToViewModel(
            track: $0,
            delegation: delegations[$0.trackId]
        ) }
        view?.didReceive(title: R.string.localizable.govTracks(preferredLanguages: selectedLocale.rLanguages))
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
