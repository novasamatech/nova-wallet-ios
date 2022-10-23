import Foundation

extension DataValidationRunner {
    static func validateVote(
        factory: GovernanceValidatorFactoryProtocol,
        params: GovernanceVoteValidatingParams,
        selectedLocale: Locale,
        feeErrorClosure: @escaping () -> Void,
        successClosure: @escaping DataValidationRunnerCompletion
    ) {
        let runner = DataValidationRunner(validators: [
            factory.enoughTokensForVoting(
                params.assetBalance,
                votingAmount: params.newVote?.voteAction.amount,
                assetInfo: params.assetInfo,
                locale: selectedLocale
            ),
            factory.hasInPlank(
                fee: params.fee,
                locale: selectedLocale,
                precision: params.assetInfo.assetPrecision,
                onError: feeErrorClosure
            ),
            factory.enoughTokensForVotingAndFee(
                params.assetBalance,
                votingAmount: params.newVote?.voteAction.amount,
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
            )
        ])

        runner.runValidation(notifyingOnSuccess: successClosure)
    }
}
