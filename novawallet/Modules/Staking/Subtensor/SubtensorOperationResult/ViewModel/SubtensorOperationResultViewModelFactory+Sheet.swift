import Foundation

extension SubtensorOperationResultViewModelFactory {
    func createSheetViewModel(
        for state: SubtensorOperationResultState,
        context: SubtensorResultViewContext,
        locale: Locale
    ) -> SubtensorResultSheetViewModel {
        switch state {
        case .progress:
            createProgressSheet(for: context.request, locale: locale)
        case let .done(outcome, _):
            createDoneSheet(for: outcome, state: state, request: context.request, locale: locale)
        case let .failed(failure, _, holdRemaining):
            createFailedSheet(
                for: failure,
                holdRemaining: holdRemaining,
                request: context.request,
                locale: locale
            )
        case .unconfirmed:
            createUnconfirmedSheet(for: context.request, locale: locale)
        }
    }
}

private extension SubtensorOperationResultViewModelFactory {
    func action(_ action: SubtensorResultAction, locale: Locale) -> SubtensorResultActionViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let title = switch action {
        case .done:
            strings.commonDone()
        case .tryAgain:
            strings.commonTryAgain()
        case .close:
            strings.commonClose()
        case .viewPosition:
            strings.stakingSubtensorResultViewPosition()
        case .discoverSubnets:
            strings.stakingSubtensorResultDiscoverSubnets()
        case .yourBittensor:
            strings.stakingSubtensorUiPortfolioTitle()
        case .backToPosition:
            strings.stakingSubtensorResultBackToPosition()
        }

        return SubtensorResultActionViewModel(action: action, title: title)
    }

    func landingActions(
        for request: SubtensorOperationResultRequest,
        locale: Locale
    ) -> [SubtensorResultActionViewModel] {
        if request.origin == .newPosition {
            return [action(.viewPosition, locale: locale)]
        }

        if request.emptiesPosition {
            return [action(.yourBittensor, locale: locale)]
        }

        return [action(.yourBittensor, locale: locale), action(.backToPosition, locale: locale)]
    }

    func networkFeeRow(
        for state: SubtensorOperationResultState,
        request: SubtensorOperationResultRequest,
        locale: Locale
    ) -> SubtensorResultSheetRowViewModel {
        let fee = networkFee(for: state, request: request, locale: locale)

        return SubtensorResultSheetRowViewModel(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.commonNetworkFee(),
            value: fee.amount,
            fiat: fee.price
        )
    }

    func createProgressSheet(
        for request: SubtensorOperationResultRequest,
        locale: Locale
    ) -> SubtensorResultSheetViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let amount = formatAmount(request.payAmount, info: taoInfo, locale: locale)

        let message = switch request.origin {
        case .addStake:
            strings.stakingSubtensorResultRootStakingMoreProgressFormat(amount)
        case .unstake:
            strings.stakingSubtensorResultRootUnstakingProgressFormat(amount)
        case .newPosition, .buyMore, .sell:
            strings.stakingSubtensorResultRootStakingProgressFormat(amount)
        }

        return SubtensorResultSheetViewModel(
            status: .progress,
            title: request.origin == .newPosition
                ? strings.stakingSubtensorResultStakingTitle()
                : strings.stakingSubtensorResultUpdatingTitle(),
            message: message,
            rows: [],
            reason: nil,
            actions: []
        )
    }

    func createDoneSheet(
        for outcome: SubtensorStakingOperationOutcome,
        state: SubtensorOperationResultState,
        request: SubtensorOperationResultRequest,
        locale: Locale
    ) -> SubtensorResultSheetViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let executed = outcome.executed?.tao ?? request.payAmount
        let executedString = formatAmount(executed, info: taoInfo, locale: locale)
        let feeRow = networkFeeRow(for: state, request: request, locale: locale)

        guard request.origin != .newPosition else {
            let validatorRow = SubtensorResultSheetRowViewModel(
                title: strings.stakingCommonValidator(),
                value: validatorName(for: request),
                fiat: nil
            )

            return SubtensorResultSheetViewModel(
                status: .done,
                title: strings.stakingSubtensorResultRootStakedFormat(executedString),
                message: strings.stakingSubtensorResultRootLiveMessage(),
                rows: [validatorRow, feeRow],
                reason: nil,
                actions: [action(.discoverSubnets, locale: locale), action(.viewPosition, locale: locale)]
            )
        }

        let isUnstake = request.origin == .unstake
        let stakeAfter = isUnstake
            ? (request.emptiesPosition ? 0 : request.stakeBefore.subtractOrZero(executed))
            : request.stakeBefore + executed
        let stakeAfterString = formatAmount(stakeAfter, info: taoInfo, locale: locale)

        let title = isUnstake
            ? strings.stakingSubtensorResultRootUnstakedFormat(executedString)
            : strings.stakingSubtensorResultRootStakedMoreFormat(executedString)

        let message = if isUnstake, request.emptiesPosition {
            strings.stakingSubtensorResultRootUnstakedAllMessage()
        } else if isUnstake {
            strings.stakingSubtensorResultRootUnstakedMessageFormat(stakeAfterString)
        } else if request.groupHotkeyCount == 1 {
            strings.stakingSubtensorResultRootStakeNowWithFormat(stakeAfterString, validatorName(for: request))
        } else {
            strings.stakingSubtensorResultRootStakeNowFormat(stakeAfterString)
        }

        let stakeAfterRow = SubtensorResultSheetRowViewModel(
            title: strings.stakingSubtensorUiStakeAfter(),
            value: stakeAfterString,
            fiat: nil
        )

        return SubtensorResultSheetViewModel(
            status: .done,
            title: title,
            message: message,
            rows: [stakeAfterRow, feeRow],
            reason: nil,
            actions: landingActions(for: request, locale: locale)
        )
    }

    func createFailedSheet(
        for failure: SubtensorStakingSubmissionFailure,
        holdRemaining: TimeInterval?,
        request: SubtensorOperationResultRequest,
        locale: Locale
    ) -> SubtensorResultSheetViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let message = switch failure.stage {
        case .notSubmitted:
            strings.stakingSubtensorResultNotSubmittedMessage()
        case .dispatched:
            strings.stakingSubtensorResultDispatchedMessage()
        case .unconfirmed:
            strings.stakingSubtensorResultUnconfirmedMessage()
        }

        let actions = failure.isRetryable
            ? [action(.close, locale: locale), action(.tryAgain, locale: locale)]
            : [action(.close, locale: locale)]

        return SubtensorResultSheetViewModel(
            status: .failed,
            title: request.origin == .unstake
                ? strings.stakingSubtensorResultUnstakingFailed()
                : strings.stakingSubtensorResultStakingFailed(),
            message: message,
            rows: [],
            reason: failureReason(for: failure, holdRemaining: holdRemaining, request: request, locale: locale),
            actions: actions
        )
    }

    func createUnconfirmedSheet(
        for request: SubtensorOperationResultRequest,
        locale: Locale
    ) -> SubtensorResultSheetViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        return SubtensorResultSheetViewModel(
            status: .pending,
            title: strings.commonTransactionSubmitted(),
            message: strings.stakingSubtensorResultUnconfirmedMessage(),
            rows: [],
            reason: nil,
            actions: landingActions(for: request, locale: locale)
        )
    }
}
