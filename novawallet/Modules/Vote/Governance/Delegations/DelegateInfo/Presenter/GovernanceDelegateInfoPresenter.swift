import Foundation
import Foundation_iOS

final class GovernanceDelegateInfoPresenter: WalletNoAccountHandling {
    weak var view: GovernanceDelegateInfoViewProtocol?
    let wireframe: GovernanceDelegateInfoWireframeProtocol
    let interactor: GovernanceDelegateInfoInteractorInputProtocol
    let logger: LoggerProtocol

    let infoViewModelFactory: GovernanceDelegateInfoViewModelFactoryProtocol
    let identityViewModelFactory: IdentityViewModelFactoryProtocol
    let tracksViewModelFactory: GovernanceTrackViewModelFactoryProtocol
    let votesViewModelFactory: ReferendumDisplayStringFactoryProtocol
    let initStats: GovernanceDelegateStats?
    let chain: ChainModel
    let accountManagementFilter: AccountManagementFilterProtocol
    let wallet: MetaAccountModel

    var details: GovernanceDelegateDetails?
    var metadata: GovernanceDelegateMetadataRemote?
    var identity: AccountIdentity?
    var delegateProfileViewModel: GovernanceDelegateProfileView.Model?
    var delegatings: [TrackIdLocal: ReferendumDelegatingLocal]?
    var tracks: [GovernanceTrackInfoLocal]?

    var delegateAddress: AccountAddress? {
        details?.stats.address ?? initStats?.address
    }

    init(
        interactor: GovernanceDelegateInfoInteractorInputProtocol,
        wireframe: GovernanceDelegateInfoWireframeProtocol,
        chain: ChainModel,
        accountManagementFilter: AccountManagementFilterProtocol,
        wallet: MetaAccountModel,
        initDelegate: GovernanceDelegateLocal?,
        infoViewModelFactory: GovernanceDelegateInfoViewModelFactoryProtocol,
        identityViewModelFactory: IdentityViewModelFactoryProtocol,
        tracksViewModelFactory: GovernanceTrackViewModelFactoryProtocol,
        votesViewModelFactory: ReferendumDisplayStringFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.wallet = wallet
        self.accountManagementFilter = accountManagementFilter
        self.infoViewModelFactory = infoViewModelFactory
        self.identityViewModelFactory = identityViewModelFactory
        self.tracksViewModelFactory = tracksViewModelFactory
        self.votesViewModelFactory = votesViewModelFactory
        initStats = initDelegate?.stats
        metadata = initDelegate?.metadata
        identity = initDelegate?.identity
        self.logger = logger
        self.localizationManager = localizationManager
    }

    func getDelegateDisplayInfo() -> GovernanceDelegateFlowDisplayInfo<AccountId>? {
        guard let delegateId = try? delegateAddress?.toAccountId() else {
            return nil
        }

        return .init(
            additions: delegateId,
            delegateMetadata: metadata,
            delegateIdentity: identity
        )
    }

    func getDelegatedTracks() -> [GovernanceTrackInfoLocal]? {
        guard let tracks = tracks, let delegatings = delegatings else {
            return nil
        }

        let targetTrackIds = Set(delegatings.keys)
        return tracks.filter { targetTrackIds.contains($0.trackId) }
    }

    func updateYourDelegations(from voting: ReferendumTracksVotingDistribution?) {
        if
            let delegateId = try? delegateAddress?.toAccountId(using: chain.chainFormat),
            let delegatings = voting?.votes.delegatings.filter({ $0.value.target == delegateId }) {
            self.delegatings = delegatings
        } else {
            delegatings = nil
        }
    }
}
