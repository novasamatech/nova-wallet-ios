import Foundation
import BigInt
import SoraFoundation

extension GovRevokeDelegationConfirmPresenter: GovernanceRevokeDelegationConfirmPresenterProtocol {
    func setup() {
        updateView()

        interactor.setup()

        refreshFee()
    }

    func presentSenderAccount() {
        guard
            let address = try? selectedAccount.chainAccount.accountId.toAddress(using: chain.chainFormat),
            let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: selectedLocale
        )
    }

    func presentDelegateAccount() {
        guard
            let address = try? delegationInfo.additions.toAddress(using: chain.chainFormat),
            let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: selectedLocale
        )
    }

    func presentTracks() {
        wireframe.showTracks(
            from: view,
            tracks: selectedTracks,
            delegations: votesResult?.value?.votes.delegatings ?? [:]
        )
    }

    func confirm() {
        guard let assetInfo = chain.utilityAssetDisplayInfo() else {
            return
        }

        let selectedTrackIds = Set(selectedTracks.map(\.trackId))

        let params = GovernanceUndelegateValidatingParams(
            assetBalance: assetBalance,
            selectedTracks: selectedTrackIds,
            delegateId: delegationInfo.additions,
            fee: fee,
            votes: votesResult?.value?.votes,
            assetInfo: assetInfo
        )

        DataValidationRunner.validateRevokeDelegation(
            factory: dataValidatingFactory,
            params: params,
            selectedLocale: selectedLocale,
            feeErrorClosure: { [weak self] in
                self?.refreshFee()
            }, successClosure: { [weak self] in
                self?.view?.didStartLoading()

                self?.interactor.submitRevoke(for: selectedTrackIds)
            }
        )
    }
}

extension GovRevokeDelegationConfirmPresenter: GovernanceRevokeDelegationConfirmInteractorOutputProtocol {
    func didReceiveSubmissionHash(_: String) {
        view?.didStopLoading()

        let selectedIds = Set(selectedTracks.map(\.trackId))
        let currentsIds = Set((votesResult?.value?.votes.delegatings ?? [:]).keys)

        let allRemoved = selectedIds == currentsIds

        wireframe.complete(on: view, allRemoved: allRemoved, locale: selectedLocale)
    }

    func didReceiveError(_ error: GovernanceRevokeDelegationInteractorError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case let .submitFailed(internalError):
            view?.didStopLoading()

            if internalError.isWatchOnlySigning {
                wireframe.presentDismissingNoSigningView(from: view)
            } else {
                _ = wireframe.present(error: internalError, from: view, locale: selectedLocale)
            }
        }
    }

    func didReceiveAssetBalance(_ assetBalance: AssetBalance?) {
        self.assetBalance = assetBalance
    }

    func didReceivePrice(_ priceData: PriceData?) {
        self.priceData = priceData

        provideFeeViewModel()
    }

    func didReceiveFee(_ fee: BigUInt) {
        self.fee = fee

        provideFeeViewModel()
    }

    func didReceiveDelegateStateDiff(_ stateDiff: GovernanceDelegateStateDiff) {
        lockDiff = stateDiff

        provideUndelegatingPeriodViewModel()
    }

    func didReceiveAccountVotes(_ votes: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>) {
        votesResult = votes

        provideYourDelegation()
        refreshLockDiff()
    }

    func didReceiveBlockTime(_ blockTime: BlockTime) {
        self.blockTime = blockTime

        provideUndelegatingPeriodViewModel()
    }

    func didReceiveBaseError(_ error: GovernanceDelegateInteractorError) {
        logger.error("Did receive base error: \(error)")

        switch error {
        case .assetBalanceFailed, .priceFailed, .accountVotesFailed,
             .blockNumberSubscriptionFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .feeFailed:
            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        case .blockTimeFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshBlockTime()
            }
        case .stateDiffFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshLockDiff()
            }
        }
    }
}

extension GovRevokeDelegationConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
