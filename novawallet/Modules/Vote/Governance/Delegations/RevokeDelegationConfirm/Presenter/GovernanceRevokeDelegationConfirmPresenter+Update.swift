import Foundation
import Foundation_iOS

extension GovRevokeDelegationConfirmPresenter {
    func provideWalletViewModel() {
        guard let viewModel = try? walletDisplayViewModelFactory.createDisplayViewModel(from: selectedAccount) else {
            return
        }

        view?.didReceiveWallet(viewModel: viewModel.cellViewModel)
    }

    func provideAccountViewModel() {
        guard let address = selectedAccount.chainAccount.toAddress() else {
            return
        }

        let viewModel = addressDisplayViewModelFactory.createViewModel(from: address)
        view?.didReceiveAccount(viewModel: viewModel)
    }

    func provideFeeViewModel() {
        if let fee = fee {
            guard let precision = chain.utilityAsset()?.displayInfo.assetPrecision else {
                return
            }

            let feeDecimal = Decimal.fromSubstrateAmount(
                fee.amount,
                precision: precision
            ) ?? 0.0

            let viewModel = balanceViewModelFactory.balanceFromPrice(feeDecimal, priceData: priceData)
                .value(for: selectedLocale)

            view?.didReceiveFee(viewModel: viewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }

    func provideDelegateViewModel() {
        guard let address = try? delegationInfo.additions.toAddress(using: chain.chainFormat) else {
            return
        }

        let name = delegationInfo.delegateIdentity?.displayName ?? delegationInfo.delegateMetadata?.name

        let addressViewModel = addressDisplayViewModelFactory.createViewModel(
            from: address,
            name: name,
            iconUrl: delegationInfo.delegateMetadata?.image
        )

        let type: GovernanceDelegateTypeView.Model?

        if let metadata = delegationInfo.delegateMetadata {
            type = metadata.isOrganization ? .organization : .individual
        } else {
            type = nil
        }

        let viewModel = GovernanceDelegateStackCell.Model(
            addressViewModel: addressViewModel,
            type: type
        )

        view?.didReceiveDelegate(viewModel: viewModel)
    }

    func provideTracksViewModel() {
        guard
            let viewModel = trackViewModelFactory.createTracksRowViewModel(
                from: selectedTracks,
                locale: selectedLocale
            ) else {
            return
        }

        view?.didReceiveTracks(viewModel: viewModel)
    }

    func provideYourDelegation() {
        guard
            let delegatings = votesResult?.value?.votes.delegatings.filter(
                { $0.value.target == delegationInfo.additions }
            ).map({ ($0.value.balance, $0.value.conviction) }),
            let firstDelegation = delegatings.first,
            delegatings.allSatisfy({ $0 == firstDelegation }) else {
            return
        }

        let votesString = referendumStringsViewModelFactory.createVotes(
            from: firstDelegation.1.votes(for: firstDelegation.0) ?? 0,
            chain: chain,
            locale: selectedLocale
        )

        let convictionString = referendumStringsViewModelFactory.createVotesDetails(
            from: firstDelegation.0,
            conviction: firstDelegation.1.decimalValue,
            chain: chain,
            locale: selectedLocale
        )

        view?.didReceiveYourDelegation(
            viewModel: .init(votes: votesString ?? "", conviction: convictionString ?? "")
        )
    }

    func provideUndelegatingPeriodViewModel() {
        guard let blockTime = blockTime, let lockDiff = lockDiff else {
            return
        }

        let viewModel = lockChangeViewModelFactory.createSinglePeriodViewModel(
            lockDiff.after?.undelegatingPeriod,
            blockTime: blockTime,
            locale: selectedLocale
        )

        view?.didReceiveUndelegatingPeriod(viewModel: viewModel)
    }

    func provideHints() {
        let hint = R.string.localizable.govRevokeDelegationConfirmHint(
            preferredLanguages: selectedLocale.rLanguages
        )

        view?.didReceiveHints(viewModel: [hint])
    }

    func refreshLockDiff() {
        guard let voting = votesResult?.value else {
            return
        }

        let delegatings = voting.votes.delegatings

        let selectedTrackIds = Set(selectedTracks.map(\.trackId))

        let optMaxDelegation = delegatings.filter { selectedTrackIds.contains($0.key) }.values.max {
            if let conviction1 = $0.conviction.decimalValue, let conviction2 = $1.conviction.decimalValue {
                return conviction1 < conviction2
            } else if $0.conviction.decimalValue != nil {
                return true
            } else {
                return false
            }
        }

        guard let maxDelegation = optMaxDelegation else {
            return
        }

        let delegation = GovernanceNewDelegation(
            delegateId: delegationInfo.additions,
            trackIds: selectedTrackIds,
            balance: maxDelegation.balance,
            conviction: maxDelegation.conviction
        )

        interactor.refreshDelegateStateDiff(for: voting, newDelegation: delegation)
    }

    func refreshFee() {
        let actions = selectedTracks.map {
            GovernanceDelegatorAction(
                delegateId: delegationInfo.additions,
                trackId: $0.trackId,
                type: .undelegate
            )
        }

        interactor.estimateFee(for: actions)
    }

    func updateView() {
        provideWalletViewModel()
        provideAccountViewModel()
        provideFeeViewModel()
        provideDelegateViewModel()
        provideTracksViewModel()
        provideYourDelegation()
        provideUndelegatingPeriodViewModel()
        provideHints()
    }
}
