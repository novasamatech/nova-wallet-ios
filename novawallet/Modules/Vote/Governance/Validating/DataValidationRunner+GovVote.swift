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
            factory.has(fee: params.fee, locale: selectedLocale, onError: feeErrorClosure),
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
        handlers _: GovernanceVoteValidatingHandlers,
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
