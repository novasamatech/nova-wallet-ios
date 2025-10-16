import Foundation
import BigInt
import Foundation_iOS

extension ReferendumsModelFactory {
    func createVotesViewModel(
        from onchainVotes: ReferendumAccountVoteLocal?,
        offchainVotes: GovernanceOffchainVotesLocal.Single?,
        chain: ChainModel,
        voterName: String?,
        locale: Locale
    ) -> YourVotesView.Model? {
        if let onchainVotes = onchainVotes {
            return createDirectVotesViewModel(
                votes: onchainVotes,
                chain: chain,
                voterName: voterName,
                locale: locale
            )
        }

        if let offchainVotes = offchainVotes {
            switch offchainVotes.voteType {
            case let .delegated(delegateVote):
                return createDelegateVotesViewModel(
                    votes: delegateVote,
                    delegateName: offchainVotes.identity?.displayName ?? offchainVotes.metadata?.name,
                    chain: chain,
                    locale: locale
                )
            case let .direct(vote):
                return createDirectVotesViewModel(votes: vote, chain: chain, voterName: voterName, locale: locale)
            }
        }

        return nil
    }

    func createDelegateVotesViewModel(
        votes: GovernanceOffchainVoting.DelegateVote,
        delegateName: String?,
        chain: ChainModel,
        locale: Locale
    ) -> YourVotesView.Model? {
        let formatVotes: (BigUInt) -> String = { votesInPlank in
            let votesString = self.stringDisplayViewModelFactory.createVotesValue(
                from: votesInPlank,
                chain: chain,
                locale: locale
            )

            return R.string(preferredLanguages: locale.rLanguages).localizable.delegateVoteBy(
                votesString ?? "",
                delegateName ?? votes.delegateAddress
            )
        }

        let votesValue = votes.delegatorPower.conviction.votes(for: votes.delegatorPower.balance) ?? 0
        let isAye = votes.delegateVote.vote.aye

        let ayesModel = isAye ? YourVoteView.Model(
            title: R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.governanceAye().uppercased(),
            description: formatVotes(votesValue),
            style: .aye
        ) : nil

        let naysModel = !isAye ? YourVoteView.Model(
            title: R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.governanceNay().uppercased(),
            description: formatVotes(votesValue),
            style: .nay
        ) : nil

        return .init(aye: ayesModel, nay: naysModel, abstain: nil)
    }

    func createDirectVotesViewModel(
        votes: ReferendumAccountVoteLocal?,
        chain: ChainModel,
        voterName: String?,
        locale: Locale
    ) -> YourVotesView.Model? {
        guard let votes = votes else {
            return nil
        }

        let formatVotes: (BigUInt) -> String = { votesInPlank in
            let votesString = self.stringDisplayViewModelFactory.createVotesValue(
                from: votesInPlank,
                chain: chain,
                locale: locale
            )

            if let voterName = voterName {
                return R.string(preferredLanguages: locale.rLanguages).localizable.govVoteBy(
                    votesString ?? "",
                    voterName
                )
            } else {
                return R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.governanceReferendumsYourVote(
                    votesString ?? ""
                )
            }
        }

        let ayesModel = votes.hasAyeVotes ? YourVoteView.Model(
            title: R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.governanceAye().uppercased(),
            description: formatVotes(votes.ayes),
            style: .aye
        ) : nil

        let naysModel = votes.hasNayVotes ? YourVoteView.Model(
            title: R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.governanceNay().uppercased(),
            description: formatVotes(votes.nays),
            style: .nay
        ) : nil

        let abstainModel = votes.hasAbstainVotes ? YourVoteView.Model(
            title: R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.governanceAbstain().uppercased(),
            description: formatVotes(votes.abstains),
            style: .abstain
        ) : nil

        return .init(
            aye: ayesModel,
            nay: naysModel,
            abstain: abstainModel
        )
    }

    func createVotingSupportProgressViewModel(
        supportAndVotes: SupportAndVotesLocal,
        chain: ChainModel,
        currentBlock: BlockNumber,
        locale: Locale
    ) -> VotingProgressView.SupportModel? {
        guard
            let chainAsset = chain.utilityAsset(),
            let supportThreshold = supportAndVotes.supportFunction?.calculateThreshold(for: currentBlock) else {
            return nil
        }

        let electorateDecimal = Decimal.fromSubstrateAmount(
            supportAndVotes.electorate,
            precision: Int16(chainAsset.precision)
        ) ?? 0

        let targetThreshold = electorateDecimal * supportThreshold

        let threshold = Decimal.fromSubstrateAmount(
            supportAndVotes.support,
            precision: Int16(chainAsset.precision)
        )
        let isCompleted = supportAndVotes.supportFraction >= supportThreshold

        let image = isCompleted ?
            R.image.iconCheckmark()?.tinted(with: R.color.colorIconPositive()!) :
            R.image.iconClose()?.tinted(with: R.color.colorIconNegative()!)

        let tokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: chainAsset.displayInfo)
        let amountFormatter = assetBalanceFormatterFactory.createDisplayFormatter(for: chainAsset.displayInfo)

        let targetThresholdString = tokenFormatter.value(for: locale).stringFromDecimal(targetThreshold) ?? ""

        let thresholdString = threshold.map {
            amountFormatter.value(for: locale).stringFromDecimal($0) ?? ""
        } ?? ""

        let text = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.governanceReferendumsThreshold(
            thresholdString,
            targetThresholdString
        )

        let titleIcon = TitleIconViewModel(title: text, icon: image)

        return .init(titleIcon: titleIcon, completed: isCompleted)
    }

    func createVotingApprovalProgressViewModel(
        supportAndVotes: SupportAndVotesLocal,
        currentBlock: BlockNumber,
        locale: Locale
    ) -> VotingProgressView.ApprovalModel {
        let ayeProgressString: String
        let nayProgressString: String

        let percentFormatter = localizedPercentFormatter.value(for: locale)

        if let approvalFraction = supportAndVotes.approvalFraction {
            ayeProgressString = percentFormatter.stringFromDecimal(approvalFraction) ?? ""
            nayProgressString = percentFormatter.stringFromDecimal(1 - approvalFraction) ?? ""
        } else {
            ayeProgressString = percentFormatter.stringFromDecimal(0) ?? ""
            nayProgressString = percentFormatter.stringFromDecimal(0) ?? ""
        }

        let passThreshold = supportAndVotes.approvalFunction?.calculateThreshold(for: currentBlock) ?? 0
        let passThresholdString = percentFormatter.stringFromDecimal(passThreshold) ?? ""

        return .init(
            passThreshold: passThreshold,
            ayeProgress: supportAndVotes.approvalFraction,
            ayeMessage: R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.governanceAyesFormat(ayeProgressString),
            passMessage: R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.governanceToPassFormat(passThresholdString),
            nayMessage: R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.governanceNaysFormat(nayProgressString)
        )
    }

    func createVotingThresholdProgressViewModel(
        for votingThreshold: VotingThresholdLocal,
        locale: Locale
    ) -> VotingProgressView.ApprovalModel {
        let ayeProgressString: String
        let nayProgressString: String

        let percentFormatter = localizedPercentFormatter.value(for: locale)

        if let approvalFraction = votingThreshold.approvalFraction {
            ayeProgressString = percentFormatter.stringFromDecimal(approvalFraction) ?? ""
            nayProgressString = percentFormatter.stringFromDecimal(1 - approvalFraction) ?? ""
        } else {
            ayeProgressString = percentFormatter.stringFromDecimal(0) ?? ""
            nayProgressString = percentFormatter.stringFromDecimal(0) ?? ""
        }

        let passThreshold = votingThreshold.calculateThreshold() ?? 0
        let passThresholdString = percentFormatter.stringFromDecimal(passThreshold) ?? ""

        return .init(
            passThreshold: passThreshold,
            ayeProgress: votingThreshold.approvalFraction,
            ayeMessage: R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.governanceAyesFormat(ayeProgressString),
            passMessage: R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.governanceToPassFormat(passThresholdString),
            nayMessage: R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.governanceNaysFormat(nayProgressString)
        )
    }

    func createGov2VotingProgressViewModel(
        supportAndVotes: SupportAndVotesLocal,
        chain: ChainModel,
        currentBlock: BlockNumber,
        locale: Locale
    ) -> VotingProgressView.Model {
        let supportModel = createVotingSupportProgressViewModel(
            supportAndVotes: supportAndVotes,
            chain: chain,
            currentBlock: currentBlock,
            locale: locale
        )

        let approvalModel = createVotingApprovalProgressViewModel(
            supportAndVotes: supportAndVotes,
            currentBlock: currentBlock,
            locale: locale
        )

        return .init(support: supportModel, approval: approvalModel)
    }

    func createGov1VotingProgressViewModel(
        votingThreshold: VotingThresholdLocal,
        locale: Locale
    ) -> VotingProgressView.Model {
        let thresholdViewModel = createVotingThresholdProgressViewModel(for: votingThreshold, locale: locale)

        return .init(support: nil, approval: thresholdViewModel)
    }
}
