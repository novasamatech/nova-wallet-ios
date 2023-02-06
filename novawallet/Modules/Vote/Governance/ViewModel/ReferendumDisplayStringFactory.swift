import Foundation
import BigInt

protocol ReferendumDisplayStringFactoryProtocol {
    func createVotesValue(from votes: BigUInt, chain: ChainModel, locale: Locale) -> String?

    func createVotes(from votes: BigUInt, chain: ChainModel, locale: Locale) -> String?

    func createVotesDetails(
        from amount: BigUInt,
        conviction: Decimal?,
        chain: ChainModel,
        locale: Locale
    ) -> String?
}

extension ReferendumDisplayStringFactoryProtocol {
    func createReferendumVotes(
        from referendum: ReferendumLocal,
        chain: ChainModel,
        locale: Locale
    ) -> ReferendumVotesViewModel? {
        guard let voting = referendum.voting else {
            return nil
        }

        let ayesString: String?
        let naysString: String?

        switch voting {
        case let .supportAndVotes(model):
            ayesString = createVotes(from: model.ayes, chain: chain, locale: locale)
            naysString = createVotes(from: model.nays, chain: chain, locale: locale)
        case let .threshold(model):
            ayesString = createVotes(from: model.ayes, chain: chain, locale: locale)
            naysString = createVotes(from: model.nays, chain: chain, locale: locale)
        }

        let aye: VoteRowView.Model? = ayesString.map {
            .init(
                title: R.string.localizable.governanceAye(preferredLanguages: locale.rLanguages),
                votes: $0
            )
        }

        let nay: VoteRowView.Model? = naysString.map {
            .init(
                title: R.string.localizable.governanceNay(preferredLanguages: locale.rLanguages),
                votes: $0
            )
        }

        return ReferendumVotesViewModel(ayes: aye, nays: nay)
    }

    func createDirectVotesViewModel(
        from vote: ReferendumAccountVoteLocal,
        chain: ChainModel,
        locale: Locale
    ) -> YourVoteRow.Model {
        let votesString = createVotes(
            from: vote.convictionValue.votes(for: vote.totalBalance) ?? 0,
            chain: chain,
            locale: locale
        )

        let convictionString = createVotesDetails(
            from: vote.totalBalance,
            conviction: vote.conviction,
            chain: chain,
            locale: locale
        )

        let voteSideString: String
        let voteSideStyle: YourVoteView.Style

        if vote.hasAyeVotes {
            voteSideString = R.string.localizable.governanceAye(preferredLanguages: locale.rLanguages)
            voteSideStyle = .ayeInverse
        } else {
            voteSideString = R.string.localizable.governanceNay(preferredLanguages: locale.rLanguages)
            voteSideStyle = .nayInverse
        }

        let voteDescription = R.string.localizable.govYourVote(preferredLanguages: locale.rLanguages)

        return YourVoteRow.Model(
            vote: .init(title: voteSideString.uppercased(), description: voteDescription, style: voteSideStyle),
            amount: .init(topValue: votesString ?? "", bottomValue: convictionString)
        )
    }

    func createDelegatorVotesViaDelegateViewModel(
        from vote: GovernanceOffchainVoting.DelegateVote,
        delegateName: String?,
        chain: ChainModel,
        locale: Locale
    ) -> YourVoteRow.Model {
        let votesValue = vote.delegatorPower.conviction.votes(for: vote.delegatorPower.balance) ?? 0

        let votesString = createVotes(
            from: votesValue,
            chain: chain,
            locale: locale
        )

        let voteSideString: String
        let voteSideStyle: YourVoteView.Style

        if vote.delegateVote.vote.aye {
            voteSideString = R.string.localizable.governanceAye(preferredLanguages: locale.rLanguages)
            voteSideStyle = .ayeInverse
        } else {
            voteSideString = R.string.localizable.governanceNay(preferredLanguages: locale.rLanguages)
            voteSideStyle = .nayInverse
        }

        let delegateName = delegateName ?? vote.delegateAddress

        let voteDescription = R.string.localizable.delegatorVotesViaDelegate(
            delegateName,
            preferredLanguages: locale.rLanguages
        )

        return YourVoteRow.Model(
            vote: .init(title: voteSideString.uppercased(), description: voteDescription, style: voteSideStyle),
            amount: .init(topValue: votesString ?? "", bottomValue: nil)
        )
    }
}

final class ReferendumDisplayStringFactory: ReferendumDisplayStringFactoryProtocol {
    let formatterFactory: AssetBalanceFormatterFactoryProtocol

    init(formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()) {
        self.formatterFactory = formatterFactory
    }

    func createVotesValue(from votes: BigUInt, chain: ChainModel, locale: Locale) -> String? {
        guard let asset = chain.utilityAsset() else {
            return nil
        }

        let displayInfo = ChainAsset(chain: chain, asset: asset).assetDisplayInfo

        let votesDecimal = Decimal.fromSubstrateAmount(votes, precision: displayInfo.assetPrecision) ?? 0

        let displayFormatter = formatterFactory.createDisplayFormatter(for: displayInfo).value(for: locale)

        return displayFormatter.stringFromDecimal(votesDecimal)
    }

    func createVotes(from votes: BigUInt, chain: ChainModel, locale: Locale) -> String? {
        guard let votesValueString = createVotesValue(from: votes, chain: chain, locale: locale) else {
            return nil
        }

        return R.string.localizable.govCommonVotesFormat(votesValueString, preferredLanguages: locale.rLanguages)
    }

    func createVotesDetails(
        from amount: BigUInt,
        conviction: Decimal?,
        chain: ChainModel,
        locale: Locale
    ) -> String? {
        guard let asset = chain.utilityAsset() else {
            return nil
        }

        let displayInfo = ChainAsset(chain: chain, asset: asset).assetDisplayInfo

        let displayFormatter = formatterFactory.createDisplayFormatter(for: displayInfo).value(for: locale)
        let tokenFormatter = formatterFactory.createTokenFormatter(for: displayInfo).value(for: locale)

        let optConvictionString = displayFormatter.stringFromDecimal(conviction ?? 0)

        let amountDecimal = Decimal.fromSubstrateAmount(amount, precision: displayInfo.assetPrecision) ?? 0
        let optAmountString = tokenFormatter.stringFromDecimal(amountDecimal)

        if let convictionString = optConvictionString, let amountString = optAmountString {
            return R.string.localizable.govCommonAmountConvictionFormat(
                amountString,
                convictionString,
                preferredLanguages: locale.rLanguages
            )
        } else {
            return nil
        }
    }
}
