import Foundation
import BigInt

protocol ReferendumVotesViewModelFactoryProtocol {
    func createReferendumVotes(
        from referendum: ReferendumLocal,
        offchainVotingAmount: ReferendumVotingAmount?,
        chain: ChainModel,
        locale: Locale
    ) -> ReferendumVotesViewModel

    func createDirectVotesViewModel(
        from vote: ReferendumAccountVoteLocal,
        chain: ChainModel,
        locale: Locale
    ) -> [YourVoteRow.Model]

    func createDelegatorVotesViaDelegateViewModel(
        from vote: GovernanceOffchainVoting.DelegateVote,
        delegateName: String?,
        chain: ChainModel,
        locale: Locale
    ) -> [YourVoteRow.Model]
}

enum ReferendumVotesViewModelFactoryProvider {
    static func factory(
        for govType: GovernanceType,
        offchainVotingAvailable: Bool,
        stringFactory: ReferendumDisplayStringFactoryProtocol = ReferendumDisplayStringFactory()
    ) -> ReferendumVotesViewModelFactoryProtocol {
        if govType == .governanceV2 {
            OpenGovReferendumVotesViewModelFactory(
                stringFactory: stringFactory,
                offchainVotingAvailable: offchainVotingAvailable
            )
        } else {
            Gov1ReferendumVotesViewModelFactory(
                stringFactory: stringFactory,
                offchainVotingAvailable: offchainVotingAvailable
            )
        }
    }
}

private typealias ReferendmVotesViewModelFactory = ReferendumVotesViewModelFactoryProtocol
    & BaseReferendumVotesViewModelFactory

// MARK: OpenGov Factory

final class OpenGovReferendumVotesViewModelFactory: ReferendmVotesViewModelFactory {
    let stringFactory: ReferendumDisplayStringFactoryProtocol
    let offchainVotingAvailable: Bool

    init(
        stringFactory: ReferendumDisplayStringFactoryProtocol,
        offchainVotingAvailable: Bool
    ) {
        self.stringFactory = stringFactory
        self.offchainVotingAvailable = offchainVotingAvailable
    }

    func createViewModel(
        title: String,
        value: BigUInt?,
        chain: ChainModel,
        locale: Locale
    ) -> VoteRowView.Model? {
        let loadableValueString: LoadableViewModelState<String>

        if
            let value,
            let valueString = stringFactory.createVotes(
                from: value,
                chain: chain,
                locale: locale
            ) {
            loadableValueString = .loaded(value: valueString)
        } else {
            loadableValueString = .loading
        }

        let viewModel = VoteRowView.Model(
            title: title,
            votes: loadableValueString
        )

        return viewModel
    }
}

// MARK: Gov1 Factory

final class Gov1ReferendumVotesViewModelFactory: ReferendmVotesViewModelFactory {
    let stringFactory: ReferendumDisplayStringFactoryProtocol
    let offchainVotingAvailable: Bool

    init(
        stringFactory: ReferendumDisplayStringFactoryProtocol,
        offchainVotingAvailable: Bool
    ) {
        self.stringFactory = stringFactory
        self.offchainVotingAvailable = offchainVotingAvailable
    }

    func createViewModel(
        title: String,
        value: BigUInt?,
        chain: ChainModel,
        locale: Locale
    ) -> VoteRowView.Model? {
        guard
            let value,
            let valueString = stringFactory.createVotes(
                from: value,
                chain: chain,
                locale: locale
            )
        else {
            return nil
        }

        let loadableValueString: LoadableViewModelState<String> = .loaded(value: valueString)

        let viewModel = VoteRowView.Model(
            title: title,
            votes: loadableValueString
        )

        return viewModel
    }
}

// MARK: BaseReferendumVotesViewModelFactory

protocol BaseReferendumVotesViewModelFactory {
    var stringFactory: ReferendumDisplayStringFactoryProtocol { get }
    var offchainVotingAvailable: Bool { get }

    func createViewModel(
        title: String,
        value: BigUInt?,
        chain: ChainModel,
        locale: Locale
    ) -> VoteRowView.Model?
}

extension BaseReferendumVotesViewModelFactory {
    func createReferendumVotes(
        from referendum: ReferendumLocal,
        offchainVotingAmount: ReferendumVotingAmount?,
        chain: ChainModel,
        locale: Locale
    ) -> ReferendumVotesViewModel {
        var ayes: BigUInt?
        var nays: BigUInt?
        let abstains: BigUInt? = offchainVotingAmount?.abstain

        if let voting = referendum.voting {
            switch voting {
            case let .supportAndVotes(model):
                ayes = model.ayes
                nays = model.nays
            case let .threshold(model):
                ayes = model.ayes
                nays = model.nays
            }
        } else if offchainVotingAvailable {
            ayes = offchainVotingAmount?.aye
            nays = offchainVotingAmount?.nay
        } else {
            return ReferendumVotesViewModel(
                ayes: nil,
                nays: nil,
                abstains: nil
            )
        }

        let aye = createViewModel(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.governanceAye(),
            value: ayes,
            chain: chain,
            locale: locale
        )
        let nay = createViewModel(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.governanceNay(),
            value: nays,
            chain: chain,
            locale: locale
        )
        let abstain: VoteRowView.Model? = {
            guard offchainVotingAvailable else { return nil }

            return createViewModel(
                title: R.string(preferredLanguages: locale.rLanguages).localizable.governanceAbstain(),
                value: abstains,
                chain: chain,
                locale: locale
            )
        }()

        return ReferendumVotesViewModel(
            ayes: aye,
            nays: nay,
            abstains: abstain
        )
    }

    func createDirectVotesViewModel(
        from vote: ReferendumAccountVoteLocal,
        chain: ChainModel,
        locale: Locale
    ) -> [YourVoteRow.Model] {
        var viewModels: [YourVoteRow.Model] = []

        if vote.hasAyeVotes {
            let viewModel = createYourVoteRowViewModel(
                vote: .init(balance: vote.ayeBalance, conviction: vote.convictionValue),
                typeName: R.string(preferredLanguages: locale.rLanguages).localizable.governanceAye(),
                style: .ayeInverse,
                chain: chain,
                locale: locale
            )

            viewModels.append(viewModel)
        }

        if vote.hasNayVotes {
            let viewModel = createYourVoteRowViewModel(
                vote: .init(balance: vote.nayBalance, conviction: vote.convictionValue),
                typeName: R.string(preferredLanguages: locale.rLanguages).localizable.governanceNay(),
                style: .nayInverse,
                chain: chain,
                locale: locale
            )

            viewModels.append(viewModel)
        }

        if vote.hasAbstainVotes {
            let viewModel = createYourVoteRowViewModel(
                vote: .init(balance: vote.abstainBalance, conviction: vote.convictionValue),
                typeName: R.string(preferredLanguages: locale.rLanguages).localizable.governanceAbstain(),
                style: .abstainInverse,
                chain: chain,
                locale: locale
            )

            viewModels.append(viewModel)
        }

        return viewModels
    }

    func createDelegatorVotesViaDelegateViewModel(
        from vote: GovernanceOffchainVoting.DelegateVote,
        delegateName: String?,
        chain: ChainModel,
        locale: Locale
    ) -> [YourVoteRow.Model] {
        let votesValue = vote.delegatorPower.conviction.votes(for: vote.delegatorPower.balance) ?? 0

        let votesString = stringFactory.createVotes(
            from: votesValue,
            chain: chain,
            locale: locale
        )

        let voteSideString: String
        let voteSideStyle: YourVoteView.Style

        if vote.delegateVote.vote.aye {
            voteSideString = R.string(preferredLanguages: locale.rLanguages).localizable.governanceAye()
            voteSideStyle = .ayeInverse
        } else {
            voteSideString = R.string(preferredLanguages: locale.rLanguages).localizable.governanceNay()
            voteSideStyle = .nayInverse
        }

        let delegateName = delegateName ?? vote.delegateAddress

        let voteDescription = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.delegatorVotesViaDelegate(delegateName)

        let viewModel = YourVoteRow.Model(
            vote: .init(title: voteSideString.uppercased(), description: voteDescription, style: voteSideStyle),
            amount: .init(topValue: votesString ?? "", bottomValue: nil)
        )

        return [viewModel]
    }

    func createYourVoteRowViewModel(
        vote: GovernanceBalanceConviction,
        typeName: String,
        style: YourVoteView.Style,
        chain: ChainModel,
        locale: Locale
    ) -> YourVoteRow.Model {
        let votesString = stringFactory.createVotes(
            from: vote.votes ?? 0,
            chain: chain,
            locale: locale
        )

        let convictionString = stringFactory.createVotesDetails(
            from: vote.balance,
            conviction: vote.conviction.decimalValue,
            chain: chain,
            locale: locale
        )

        let voteDescription = R.string(preferredLanguages: locale.rLanguages).localizable.govYourVote()

        return YourVoteRow.Model(
            vote: .init(title: typeName.uppercased(), description: voteDescription, style: style),
            amount: .init(topValue: votesString ?? "", bottomValue: convictionString)
        )
    }
}
