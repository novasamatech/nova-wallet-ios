import Foundation
import SoraFoundation

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

    private var details: GovernanceDelegateDetails?
    private var metadata: GovernanceDelegateMetadataRemote?
    private var identity: AccountIdentity?
    private var delegateProfileViewModel: GovernanceDelegateProfileView.Model?
    private var delegatings: [TrackIdLocal: ReferendumDelegatingLocal]?
    private var tracks: [GovernanceTrackInfoLocal]?

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

    private func getDelegateDisplayInfo() -> GovernanceDelegateFlowDisplayInfo<AccountId>? {
        guard let delegateId = try? delegateAddress?.toAccountId() else {
            return nil
        }

        return .init(
            additions: delegateId,
            delegateMetadata: metadata,
            delegateIdentity: identity
        )
    }

    private func updateYourDelegations(from voting: ReferendumTracksVotingDistribution?) {
        if
            let delegateId = try? delegateAddress?.toAccountId(using: chain.chainFormat),
            let delegatings = voting?.votes.delegatings.filter({ $0.value.target == delegateId }) {
            self.delegatings = delegatings
        } else {
            delegatings = nil
        }
    }

    private func getDelegatedTracks() -> [GovernanceTrackInfoLocal]? {
        guard let tracks = tracks, let delegatings = delegatings else {
            return nil
        }

        let targetTrackIds = Set(delegatings.keys)
        return tracks.filter { targetTrackIds.contains($0.trackId) }
    }

    private func provideDelegateViewModel() {
        guard let delegateAddress = delegateAddress else {
            return
        }

        let viewModel = infoViewModelFactory.createDelegateViewModel(
            from: delegateAddress,
            metadata: metadata,
            identity: identity
        )

        delegateProfileViewModel = viewModel.profileViewModel
        view?.didReceiveDelegate(viewModel: viewModel)
    }

    private func provideStatsViewModel() {
        let optViewModel: GovernanceDelegateInfoViewModel.Stats?

        if let details = details {
            optViewModel = infoViewModelFactory.createStatsViewModel(
                from: details,
                chain: chain,
                locale: selectedLocale
            )
        } else if let stats = initStats {
            optViewModel = infoViewModelFactory.createStatsViewModel(
                using: stats,
                chain: chain,
                locale: selectedLocale
            )
        } else {
            optViewModel = nil
        }

        guard let viewModel = optViewModel else {
            return
        }

        view?.didReceiveStats(viewModel: viewModel)
    }

    private func provideYourDelegations() {
        if
            let delegatings = delegatings,
            let delegating = delegatings.first?.value,
            let targetTracks = getDelegatedTracks() {
            guard
                let tracksViewModel = tracksViewModelFactory.createTracksRowViewModel(
                    from: targetTracks,
                    locale: selectedLocale
                ) else {
                return
            }

            if delegatings.count == 1 {
                let votes = votesViewModelFactory.createVotes(
                    from: delegating.conviction.votes(for: delegating.balance) ?? 0,
                    chain: chain,
                    locale: selectedLocale
                )

                let conviction = votesViewModelFactory.createVotesDetails(
                    from: delegating.balance,
                    conviction: delegating.conviction.decimalValue,
                    chain: chain,
                    locale: selectedLocale
                )

                view?.didReceiveYourDelegation(
                    viewModel: .init(
                        tracks: tracksViewModel,
                        delegation: .init(
                            votes: votes ?? "",
                            conviction: conviction ?? ""
                        )
                    )
                )
            } else {
                view?.didReceiveYourDelegation(
                    viewModel: .init(
                        tracks: tracksViewModel,
                        delegation: nil
                    )
                )
            }

        } else {
            view?.didReceiveYourDelegation(viewModel: nil)
        }
    }

    private func provideIdentity() {
        if let identity = identity {
            let viewModel = identityViewModelFactory.createIdentityViewModel(
                from: identity,
                locale: selectedLocale
            )

            view?.didReceiveIdentity(items: viewModel)
        } else {
            view?.didReceiveIdentity(items: nil)
        }
    }

    private func provideViewModels() {
        provideDelegateViewModel()
        provideStatsViewModel()
        provideYourDelegations()
        provideIdentity()
    }
}

extension GovernanceDelegateInfoPresenter: GovernanceDelegateInfoPresenterProtocol {
    func setup() {
        provideViewModels()

        interactor.setup()
    }

    func presentFullDescription() {
        guard let delegateProfileViewModel = delegateProfileViewModel,
              let longDescription = metadata?.longDescription else {
            return
        }

        wireframe.showFullDescription(
            from: view,
            name: delegateProfileViewModel.name,
            longDescription: longDescription
        )
    }

    func presentDelegations() {
        guard let address = delegateAddress else {
            return
        }

        wireframe.showDelegations(from: view, delegateAddress: address)
    }

    func presentRecentVotes() {
        guard let address = delegateAddress else {
            return
        }

        wireframe.showRecentVotes(
            from: view,
            delegateAddress: address,
            delegateName: delegateProfileViewModel?.name
        )
    }

    func presentAllVotes() {
        guard let address = delegateAddress else {
            return
        }

        wireframe.showAllVotes(
            from: view,
            delegateAddress: address,
            delegateName: delegateProfileViewModel?.name
        )
    }

    func presentIdentityItem(_ item: ValidatorInfoViewModel.IdentityItemValue) {
        guard case let .link(value, tag) = item, let view = view else {
            return
        }

        wireframe.presentIdentityItem(
            from: view,
            tag: tag,
            value: value,
            locale: selectedLocale
        )
    }

    func presentAccountOptions() {
        guard let address = delegateAddress, let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: selectedLocale
        )
    }

    func addDelegation() {
        guard let view = view else {
            return
        }

        validateAccount(
            from: .init(
                wallet: wallet,
                chain: chain,
                accountManagementFilter: accountManagementFilter,
                successHandler: { [weak self] in
                    guard let displayInfo = self?.getDelegateDisplayInfo() else {
                        return
                    }

                    self?.wireframe.showAddDelegation(from: view, delegate: displayInfo)
                },
                newAccountHandler: { [weak self] in
                    guard let wallet = self?.wallet else {
                        return
                    }

                    self?.wireframe.showWalletDetails(from: view, wallet: wallet)
                }
            ),
            view: view,
            wireframe: wireframe,
            locale: selectedLocale
        )
    }

    func editDelegation() {
        guard let displayInfo = getDelegateDisplayInfo() else {
            return
        }

        wireframe.showEditDelegation(from: view, delegate: displayInfo)
    }

    func revokeDelegation() {
        guard let displayInfo = getDelegateDisplayInfo() else {
            return
        }

        wireframe.showRevokeDelegation(from: view, delegate: displayInfo)
    }

    func showTracks() {
        guard let delegatings = delegatings, !delegatings.isEmpty, let tracks = getDelegatedTracks() else {
            return
        }

        wireframe.showTracks(from: view, tracks: tracks, delegations: delegatings)
    }
}

extension GovernanceDelegateInfoPresenter: GovernanceDelegateInfoInteractorOutputProtocol {
    func didReceiveDetails(_ details: GovernanceDelegateDetails?) {
        if self.details != details {
            self.details = details

            provideDelegateViewModel()
            provideStatsViewModel()
            provideYourDelegations()
        }
    }

    func didReceiveMetadata(_ metadata: GovernanceDelegateMetadataRemote?) {
        if metadata != self.metadata {
            self.metadata = metadata

            provideDelegateViewModel()
        }
    }

    func didReceiveIdentity(_ identity: AccountIdentity?) {
        if self.identity != identity {
            self.identity = identity

            provideDelegateViewModel()
            provideIdentity()
        }
    }

    func didReceiveVotingResult(_ result: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>) {
        updateYourDelegations(from: result.value)

        provideYourDelegations()
    }

    func didReceiveTracks(_ tracks: [GovernanceTrackInfoLocal]) {
        self.tracks = tracks

        provideYourDelegations()
    }

    func didReceiveError(_ error: GovernanceDelegateInfoError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .detailsFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshDetails()
            }
        case .metadataSubscriptionFailed, .blockSubscriptionFailed, .blockTimeFetchFailed,
             .votesSubscriptionFailed:
            interactor.remakeSubscriptions()
        case .identityFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshIdentity()
            }
        case .tracksFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshTracks()
            }
        }
    }
}

extension GovernanceDelegateInfoPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModels()
        }
    }
}
