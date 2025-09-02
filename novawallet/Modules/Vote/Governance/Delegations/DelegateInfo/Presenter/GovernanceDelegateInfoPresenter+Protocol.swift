import Foundation
import Foundation_iOS

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
                },
                addAccountAskMessage: R.string.localizable.delegationsAccountMissingMessage(
                    chain.name,
                    preferredLanguages: selectedLocale.rLanguages
                )
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

    func open(url: URL) {
        guard let view = view else {
            return
        }

        wireframe.showWeb(url: url, from: view, style: .automatic)
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
