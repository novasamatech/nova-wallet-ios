import Foundation
import Foundation_iOS

extension GovernanceDelegateConfirmPresenter {
    func provideAmountViewModel() {
        guard
            let precision = chain.utilityAsset()?.displayInfo.assetPrecision,
            let decimalAmount = Decimal.fromSubstrateAmount(
                delegation.balance,
                precision: precision
            ) else {
            return
        }

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            decimalAmount,
            priceData: priceData
        ).value(for: selectedLocale)

        view?.didReceiveAmount(viewModel: viewModel)
    }

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
        guard let address = try? delegation.delegateId.toAddress(using: chain.chainFormat) else {
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
                from: delegationInfo.additions,
                locale: selectedLocale
            ) else {
            return
        }

        view?.didReceiveTracks(viewModel: viewModel)
    }

    func provideYourDelegation() {
        let votesString = referendumStringsViewModelFactory.createVotes(
            from: delegation.conviction.votes(for: delegation.balance) ?? 0,
            chain: chain,
            locale: selectedLocale
        )

        let convictionString = referendumStringsViewModelFactory.createVotesDetails(
            from: delegation.balance,
            conviction: delegation.conviction.decimalValue,
            chain: chain,
            locale: selectedLocale
        )

        view?.didReceiveYourDelegation(
            viewModel: .init(votes: votesString ?? "", conviction: convictionString ?? "")
        )
    }

    func provideTransferableAmountViewModel() {
        guard
            let assetBalance = assetBalance,
            let assetLocks = assetLocks,
            let lockDiff = lockDiff,
            let viewModel = lockChangeViewModelFactory.createTransferableAmountViewModel(
                govLockedAmount: lockDiff.after?.maxLockedAmount,
                balance: assetBalance,
                locks: assetLocks,
                locale: selectedLocale
            ) else {
            return
        }

        view?.didReceiveTransferableAmount(viewModel: viewModel)
    }

    func provideLockedAmountViewModel() {
        guard
            let lockDiff = lockDiff,
            let viewModel = lockChangeViewModelFactory.createAmountTransitionAfterDelegatingViewModel(
                from: lockDiff,
                locale: selectedLocale
            ) else {
            return
        }

        view?.didReceiveLockedAmount(viewModel: viewModel)
    }

    func provideUndelegatingPeriodViewModel() {
        guard
            let lockDiff = lockDiff,
            let blockTime = blockTime else {
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
        let hint1 = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.govAddDelegateHint1()
        let hint2 = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.govAddDelegateHint2()

        view?.didReceiveHints(viewModel: [hint1, hint2])
    }

    func refreshFee() {
        guard let voting = votesResult?.value else {
            return
        }

        let actions = delegation.createActions(from: voting)

        interactor.estimateFee(for: actions)
    }

    func refreshLockDiff() {
        guard let trackVoting = votesResult?.value else {
            return
        }

        interactor.refreshDelegateStateDiff(for: trackVoting, newDelegation: delegation)
    }

    func updateView() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFeeViewModel()
        provideDelegateViewModel()
        provideTracksViewModel()
        provideYourDelegation()
        provideTransferableAmountViewModel()
        provideLockedAmountViewModel()
        provideUndelegatingPeriodViewModel()
        provideHints()
    }
}
