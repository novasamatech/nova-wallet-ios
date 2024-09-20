import Foundation

extension DataValidationRunner {
    static func validateVote(
        factory: GovernanceValidatorFactoryProtocol,
        params: GovernanceVoteValidatingParams,
        selectedLocale: Locale,
        handlers: GovernanceVoteValidatingHandlers,
        successClosure: @escaping DataValidationRunnerCompletion
    ) {
        let runner = DataValidationRunner(validators: [
            factory.enoughTokensForVoting(
                params.assetBalance,
                votingAmount: params.newVote?.voteAction.amount(),
                assetInfo: params.assetInfo,
                locale: selectedLocale
            ),
            factory.has(
                fee: params.fee,
                locale: selectedLocale,
                onError: handlers.feeErrorClosure
            ),
            factory.enoughTokensForVotingAndFee(
                params.assetBalance,
                votingAmount: params.newVote?.voteAction.amount(),
                fee: params.fee,
                assetInfo: params.assetInfo,
                locale: selectedLocale
            ),
            factory.referendumNotEnded(params.referendum, locale: selectedLocale),
            factory.notDelegating(
                params.votes,
                track: params.referendum?.trackId,
                locale: selectedLocale
            ),
            factory.maxVotesNotReached(
                params.votes,
                track: params.referendum?.trackId,
                locale: selectedLocale
            ),
            factory.voteMatchesConviction(
                with: params.newVote,
                selectedConviction: params.selectedConviction,
                convictionUpdateClosure: handlers.convictionUpdateClosure,
                locale: selectedLocale
            )
        ])

        runner.runValidation(notifyingOnSuccess: successClosure)
    }

    static func validateVotesBatch(
        factory: GovernanceValidatorFactoryProtocol,
        params: GovernanceVoteBatchValidatingParams,
        selectedLocale: Locale,
        handlers: GovernanceVoteValidatingHandlers,
        successClosure: @escaping DataValidationRunnerCompletion,
        maxAmountErrorClosure: @escaping () -> Void
    ) {
        var validators: [DataValidating] = [
            factory.enoughTokensForBatchVoting(
                params.assetBalance,
                votingAmount: params.maxAmount,
                assetInfo: params.assetInfo,
                locale: selectedLocale,
                maxAmountErrorClosure: maxAmountErrorClosure
            ),
            factory.has(
                fee: params.fee,
                locale: selectedLocale,
                onError: handlers.feeErrorClosure
            ),
            factory.enoughTokensForVotingAndFee(
                params.assetBalance,
                votingAmount: params.maxAmount,
                fee: params.fee,
                assetInfo: params.assetInfo,
                locale: selectedLocale
            )
        ]

        let notEndedValidations = params.referendums?.map {
            factory.referendumNotEnded(
                $0,
                locale: selectedLocale
            )
        }
        let notDelegatingValidations = params.referendums?.map {
            factory.notDelegating(
                params.votes,
                track: $0.trackId,
                locale: selectedLocale
            )
        }
        let maxVotesNotReachedValidations = params.referendums?.map {
            factory.maxVotesNotReached(
                params.votes,
                track: $0.trackId,
                locale: selectedLocale
            )
        }

        validators.append(contentsOf: notEndedValidations ?? [])
        validators.append(contentsOf: notDelegatingValidations ?? [])
        validators.append(contentsOf: maxVotesNotReachedValidations ?? [])

        let runner = DataValidationRunner(validators: validators)

        runner.runValidation(notifyingOnSuccess: successClosure)
    }

    static func validateDelegate(
        factory: GovernanceValidatorFactoryProtocol,
        params: GovernanceDelegateValidatingParams,
        selectedLocale: Locale,
        feeErrorClosure: @escaping () -> Void,
        successClosure: @escaping DataValidationRunnerCompletion
    ) {
        let runner = DataValidationRunner(validators: [
            factory.enoughTokensForVoting(
                params.assetBalance,
                votingAmount: params.newDelegation?.balance,
                assetInfo: params.assetInfo,
                locale: selectedLocale
            ),
            factory.has(
                fee: params.fee,
                locale: selectedLocale,
                onError: feeErrorClosure
            ),
            factory.enoughTokensForVotingAndFee(
                params.assetBalance,
                votingAmount: params.newDelegation?.balance,
                fee: params.fee,
                assetInfo: params.assetInfo,
                locale: selectedLocale
            ),
            factory.notVoting(
                params.votes,
                tracks: params.newDelegation?.trackIds,
                locale: selectedLocale
            ),
            factory.notSelfDelegating(
                selfId: params.selfAccountId,
                delegateId: params.newDelegation?.delegateId,
                locale: selectedLocale
            )
        ])

        runner.runValidation(notifyingOnSuccess: successClosure)
    }

    static func validateRevokeDelegation(
        factory: GovernanceValidatorFactoryProtocol,
        params: GovernanceUndelegateValidatingParams,
        selectedLocale: Locale,
        feeErrorClosure: @escaping () -> Void,
        successClosure: @escaping DataValidationRunnerCompletion
    ) {
        let runner = DataValidationRunner(validators: [
            factory.has(fee: params.fee, locale: selectedLocale, onError: feeErrorClosure),
            factory.canPayFeeInPlank(
                balance: params.assetBalance?.transferable,
                fee: params.fee,
                asset: params.assetInfo,
                locale: selectedLocale
            ),
            factory.delegating(
                params.votes,
                tracks: params.selectedTracks,
                delegateId: params.delegateId,
                locale: selectedLocale
            )
        ])

        runner.runValidation(notifyingOnSuccess: successClosure)
    }

    static func validateVotingPower(
        factory: GovernanceValidatorFactoryProtocol,
        params: GovernanceVotePowerValidatingParams,
        selectedLocale: Locale,
        successClosure: @escaping DataValidationRunnerCompletion
    ) {
        let runner = DataValidationRunner(validators: [
            factory.enoughTokensForVoting(
                params.assetBalance,
                votingAmount: params.votePower?.amount,
                assetInfo: params.assetInfo,
                locale: selectedLocale
            )
        ])

        runner.runValidation(notifyingOnSuccess: successClosure)
    }
}
