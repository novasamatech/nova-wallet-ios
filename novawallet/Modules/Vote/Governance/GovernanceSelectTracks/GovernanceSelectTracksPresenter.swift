import Foundation
import SoraFoundation

class GovernanceSelectTracksPresenter: SelectTracksPresenter, GovernanceSelectTracksPresenterProtocol {
    weak var baseView: GovernanceSelectTracksViewProtocol? {
        get {
            selectTracksView as? GovernanceSelectTracksViewProtocol
        }
        set {
            selectTracksView = newValue
        }
    }

    var baseWireframe: GovernanceSelectTracksWireframeProtocol? {
        selectTracksWireframe as? GovernanceSelectTracksWireframeProtocol
    }

    var baseInteractor: GovernanceSelectTracksInteractorInputProtocol? {
        selectTracksInteractor as? GovernanceSelectTracksInteractorInputProtocol
    }

    private(set) var votingResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?

    init(
        baseInteractor: GovernanceSelectTracksInteractorInputProtocol,
        baseWireframe: GovernanceSelectTracksWireframeProtocol,
        chain: ChainModel,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        super.init(
            interactor: baseInteractor,
            wireframe: baseWireframe,
            chain: chain,
            localizationManager: localizationManager,
            logger: logger
        )
    }

    // MARK: - GovernanceSelectTracksPresenterProtocol

    override func proceed() {
        guard let selectedTrackTypes = selectedTracks, let allTracks = tracks else {
            return
        }

        let selectedTracks = allTracks.filter { track in
            guard let trackType = ReferendumTrackType(rawValue: track.name) else {
                return false
            }

            return selectedTrackTypes.contains(trackType)
        }

        baseWireframe?.proceed(from: baseView, tracks: selectedTracks)
    }
}

extension GovernanceSelectTracksPresenter: GovernanceSelectTracksInteractorOutputProtocol {
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
            baseWireframe?.presentRequestStatus(on: baseView, locale: nil) { [weak self] in
                self?.baseInteractor?.retryTracksFetch()
            }
        case .votesSubsctiptionFailed:
            baseWireframe?.presentRequestStatus(on: baseView, locale: nil) { [weak self] in
                self?.baseInteractor?.remakeSubscriptions()
            }
        }
    }
}
