import Foundation
import Foundation_iOS

final class GovRevokeDelegationTracksPresenter: GovernanceSelectTracksPresenter {
    let delegateId: AccountId

    init(
        interactor: GovernanceSelectTracksInteractorInputProtocol,
        wireframe: GovernanceSelectTracksWireframeProtocol,
        delegateId: AccountId,
        chain: ChainModel,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.delegateId = delegateId

        super.init(
            baseInteractor: interactor,
            baseWireframe: wireframe,
            chain: chain,
            localizationManager: localizationManager,
            logger: logger
        )
    }

    override func setupAvailableTracks() {
        guard let delegatings = votingResult?.value?.votes.delegatings.filter({ $0.value.target == delegateId }) else {
            return
        }

        availableTrackIds = Set(delegatings.keys)
    }

    override func setupSelectedTracks() {
        guard tracks != nil, votingResult != nil else {
            return
        }

        selectedTrackIds = Set()
    }
}
