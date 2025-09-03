import Foundation
import BigInt

protocol DelegationReferendumVotersViewModelFactoryProtocol {
    func createViewModel(
        voters: ReferendumVoterLocals,
        type: ReferendumVotersType,
        chain: ChainModel,
        locale: Locale
    ) -> [DelegationReferendumVotersModel]
}

final class DelegationReferendumVotersViewModelFactory: DelegationReferendumVotersViewModelFactoryProtocol {
    let stringFactory: ReferendumDisplayStringFactoryProtocol
    let displayAddressFactory = DisplayAddressViewModelFactory()

    init(stringFactory: ReferendumDisplayStringFactoryProtocol) {
        self.stringFactory = stringFactory
    }

    func createViewModel(
        voters: ReferendumVoterLocals,
        type: ReferendumVotersType,
        chain: ChainModel,
        locale: Locale
    ) -> [DelegationReferendumVotersModel] {
        voters.model.filter { voter in
            switch type {
            case .ayes:
                return voter.vote.hasAyeVotes
            case .nays:
                return voter.vote.hasNayVotes
            case .abstains:
                return voter.vote.hasAbstainVotes
            }
        }
        .sorted {
            let lhsDelegatorsVotes = $0.delegatorsVotes
            let rhsDelegatorsVotes = $1.delegatorsVotes
            switch type {
            case .ayes:
                return $0.vote.ayes + lhsDelegatorsVotes > $1.vote.ayes + rhsDelegatorsVotes
            case .nays:
                return $0.vote.nays + lhsDelegatorsVotes > $1.vote.nays + rhsDelegatorsVotes
            case .abstains:
                return $0.vote.abstains + lhsDelegatorsVotes > $1.vote.abstains + rhsDelegatorsVotes
            }
        }.compactMap {
            self.createSection(
                type: type,
                chain: chain,
                locale: locale,
                identites: voters.identities,
                voter: $0,
                metadata: voters.metadata
            )
        }
    }

    private func createSection(
        type: ReferendumVotersType,
        chain: ChainModel,
        locale: Locale,
        identites: [AccountId: AccountIdentity],
        voter: ReferendumVoterLocal,
        metadata: [AccountId: GovernanceDelegateMetadataRemote]
    ) -> DelegationReferendumVotersModel? {
        if voter.delegators.isEmpty {
            return createSingleSectionViewModel(
                type: type,
                chain: chain,
                locale: locale,
                identites: identites,
                voter: voter,
                metadata: metadata[voter.accountId]
            )
        } else {
            let sortedDelegations = voter.delegators.sorted(by: {
                let lhsVotes = $0.power.conviction.votes(for: $0.power.balance) ?? 0
                let rhsVotes = $1.power.conviction.votes(for: $1.power.balance) ?? 0
                return lhsVotes > rhsVotes
            })
            return createGroupSectionViewModel(
                referendumVotersType: type,
                chain: chain,
                locale: locale,
                voter: voter,
                delegations: sortedDelegations,
                identites: identites,
                metadata: metadata
            )
        }
    }

    private func displayAddressViewModel(
        voter: ReferendumVoterLocal,
        address: AccountAddress,
        identites: [AccountId: AccountIdentity],
        metadata: GovernanceDelegateMetadataRemote?
    ) -> DisplayAddressViewModel {
        if let displayName = identites[voter.accountId]?.displayName,
           !displayName.isEmpty {
            return displayAddressFactory.createViewModel(
                from: address,
                name: displayName,
                iconUrl: metadata?.image
            )
        } else if let displayName = metadata?.name,
                  !displayName.isEmpty {
            return displayAddressFactory.createViewModel(
                from: address,
                name: displayName,
                iconUrl: metadata?.image
            )
        } else {
            return displayAddressFactory.createViewModel(from: address)
        }
    }

    private func createGroupSectionViewModel(
        referendumVotersType: ReferendumVotersType,
        chain: ChainModel,
        locale: Locale,
        voter: ReferendumVoterLocal,
        delegations: [GovernanceOffchainDelegation],
        identites: [AccountId: AccountIdentity],
        metadata: [AccountId: GovernanceDelegateMetadataRemote]
    ) -> DelegationReferendumVotersModel? {
        guard let voterAddress = try? voter.accountId.toAddress(using: chain.chainFormat) else {
            return nil
        }

        let voterMetadata = metadata[voter.accountId]
        let displayAddressViewModel = displayAddressViewModel(
            voter: voter,
            address: voterAddress,
            identites: identites,
            metadata: voterMetadata
        )

        let votes: BigUInt
        let amountInPlank: BigUInt

        switch referendumVotersType {
        case .ayes:
            votes = voter.vote.ayes
            amountInPlank = voter.vote.ayeBalance
        case .nays:
            votes = voter.vote.nays
            amountInPlank = voter.vote.nayBalance
        case .abstains:
            votes = voter.vote.abstains
            amountInPlank = voter.vote.abstainBalance
        }

        let totalVotes = votes + voter.delegatorsVotes
        let votesString = stringFactory.createVotes(from: votes, chain: chain, locale: locale) ?? ""
        let details = stringFactory.createVotesDetails(
            from: amountInPlank,
            conviction: voter.vote.conviction,
            chain: chain,
            locale: locale
        )
        let totalVotesString = stringFactory.createVotes(from: totalVotes, chain: chain, locale: locale)
        let type: GovernanceDelegateTypeView.Model? = voterMetadata.map {
            $0.isOrganization ? .organization : .individual
        }
        let delegateInfo = DelegateInfoView.Model(
            type: type,
            addressViewModel: displayAddressViewModel
        )
        let delegateCellModel = DelegateSingleVoteCollectionViewCell.Model(
            delegateInfo: delegateInfo,
            votes: .init(
                topValue: votesString,
                bottomValue: details
            )
        )

        var cells = delegations.map {
            self.createDelegationViewModel(
                chain: chain,
                locale: locale,
                identites: identites,
                delegation: $0,
                metadata: metadata
            )
        }

        if let delegateCellPosition = delegations.firstIndex(where: {
            guard let delegatorVotes = $0.power.conviction.votes(for: $0.power.balance) else {
                return false
            }
            return delegatorVotes < votes
        }) {
            cells.insert(delegateCellModel, at: delegateCellPosition)
        } else {
            cells.append(delegateCellModel)
        }

        let delegateHeaderModel = DelegateGroupVotesHeader.Model(
            delegateInfo: delegateInfo,
            votes: totalVotesString ?? ""
        )

        return .grouped(.init(
            id: voterAddress,
            model: delegateHeaderModel,
            cells: cells.compactMap { $0 }
        ))
    }

    private func createSingleSectionViewModel(
        type: ReferendumVotersType,
        chain: ChainModel,
        locale: Locale,
        identites: [AccountId: AccountIdentity],
        voter: ReferendumVoterLocal,
        metadata: GovernanceDelegateMetadataRemote?
    ) -> DelegationReferendumVotersModel? {
        guard let address = try? voter.accountId.toAddress(using: chain.chainFormat) else {
            return nil
        }

        let displayAddressViewModel = displayAddressViewModel(
            voter: voter,
            address: address,
            identites: identites,
            metadata: metadata
        )

        let amountInPlank: BigUInt
        let votes: BigUInt

        switch type {
        case .ayes:
            amountInPlank = voter.vote.ayeBalance
            votes = voter.vote.ayes
        case .nays:
            amountInPlank = voter.vote.nayBalance
            votes = voter.vote.nays
        case .abstains:
            amountInPlank = voter.vote.abstainBalance
            votes = voter.vote.abstains
        }

        let votesString = stringFactory.createVotes(from: votes, chain: chain, locale: locale)
        let details = stringFactory.createVotesDetails(
            from: amountInPlank,
            conviction: voter.vote.conviction,
            chain: chain,
            locale: locale
        )

        let type: GovernanceDelegateTypeView.Model? = metadata.map {
            $0.isOrganization ? .organization : .individual
        }

        let delegateInfo = DelegateInfoView.Model(type: type, addressViewModel: displayAddressViewModel)

        return .single(.init(
            id: displayAddressViewModel.address,
            model: .init(
                delegateInfo: delegateInfo,
                votes: .init(
                    topValue: votesString ?? "",
                    bottomValue: details
                )
            )
        ))
    }

    private func createDelegationViewModel(
        chain: ChainModel,
        locale: Locale,
        identites: [AccountId: AccountIdentity],
        delegation: GovernanceOffchainDelegation,
        metadata: [AccountId: GovernanceDelegateMetadataRemote]
    ) -> DelegateSingleVoteCollectionViewCell.Model? {
        let address = delegation.delegator

        guard let accountId = try? address.toAccountId() else {
            return nil
        }

        let delegationMetadata = metadata[accountId]
        let displayAddressViewModel: DisplayAddressViewModel
        if let displayName = identites[accountId]?.displayName,
           !displayName.isEmpty {
            displayAddressViewModel = displayAddressFactory.createViewModel(
                from: address,
                name: displayName,
                iconUrl: delegationMetadata?.image
            )
        } else if let displayName = delegationMetadata?.name,
                  !displayName.isEmpty {
            displayAddressViewModel = displayAddressFactory.createViewModel(
                from: address,
                name: displayName,
                iconUrl: delegationMetadata?.image
            )
        } else {
            displayAddressViewModel = displayAddressFactory.createViewModel(from: address)
        }

        let amountInPlank = delegation.power.balance
        let votes: BigUInt = delegation.power.conviction.votes(for: amountInPlank) ?? 0

        let votesString = stringFactory.createVotes(from: votes, chain: chain, locale: locale)
        let details = stringFactory.createVotesDetails(
            from: amountInPlank,
            conviction: delegation.power.conviction.decimalValue,
            chain: chain,
            locale: locale
        )

        let type: GovernanceDelegateTypeView.Model? = delegationMetadata.map {
            $0.isOrganization ? .organization : .individual
        }

        let delegateInfo = DelegateInfoView.Model(type: type, addressViewModel: displayAddressViewModel)

        return .init(
            delegateInfo: delegateInfo,
            votes: .init(
                topValue: votesString ?? "",
                bottomValue: details
            )
        )
    }
}
