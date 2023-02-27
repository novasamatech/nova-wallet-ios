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
            }
        }
        .sorted {
            switch type {
            case .ayes:
                return $0.vote.ayes > $1.vote.ayes
            case .nays:
                return $0.vote.nays > $1.vote.nays
            }
        }.compactMap {
            self.createSection(
                type: type,
                chain: chain,
                locale: locale,
                identites: voters.identities,
                voter: $0,
                metadata: voters.metadata[$0.accountId]
            )
        }
    }

    private func createSection(
        type: ReferendumVotersType,
        chain: ChainModel,
        locale: Locale,
        identites: [AccountId: AccountIdentity],
        voter: ReferendumVoterLocal,
        metadata: GovernanceDelegateMetadataRemote?
    ) -> DelegationReferendumVotersModel? {
        if voter.delegators.isEmpty {
            return createSingleSectionViewModel(type: type, chain: chain, locale: locale, identites: identites, voter: voter, metadata: metadata)
        } else {
            let sortedDelegations = voter.delegators.sorted(by: {
                let lhsVotes = $0.power.conviction.votes(for: $0.power.balance) ?? 0
                let rhsVotes = $1.power.conviction.votes(for: $1.power.balance) ?? 0
                return lhsVotes > rhsVotes
            })
            return createGroupSectionViewModel(
                chain: chain,
                locale: locale,
                delegator: voter,
                delegations: sortedDelegations,
                identites: identites,
                metadata: metadata
            )
        }
    }

    private func createGroupSectionViewModel(
        chain: ChainModel,
        locale: Locale,
        delegator: ReferendumVoterLocal,
        delegations: [GovernanceOffchainDelegation],
        identites: [AccountId: AccountIdentity],
        metadata: GovernanceDelegateMetadataRemote?
    ) -> DelegationReferendumVotersModel? {
        guard let address = try? delegator.accountId.toAddress(using: chain.chainFormat) else {
            return nil
        }

        guard !delegations.isEmpty else {
            return nil
        }

        let displayAddressViewModel: DisplayAddressViewModel
        if let displayName = identites[delegator.accountId]?.displayName {
            let displayAddress = DisplayAddress(address: address, username: displayName)
            displayAddressViewModel = displayAddressFactory.createViewModel(from: displayAddress)
        } else {
            displayAddressViewModel = displayAddressFactory.createViewModel(from: address)
        }

        let votes = delegations.reduce(into: 0) {
            $0 += ($1.power.conviction.votes(for: $1.power.balance) ?? 0)
        }
        let votesString = stringFactory.createVotes(from: votes, chain: chain, locale: locale)

        let cells = delegations.compactMap {
            self.createDelegationViewModel(
                chain: chain,
                locale: locale,
                identites: identites,
                delegation: $0,
                metadata: metadata
            )
        }

        let type: GovernanceDelegateTypeView.Model? = metadata.map {
            $0.isOrganization ? .organization : .individual
        }

        let model = DelegateGroupVotesHeader.Model(
            delegateInfo: .init(
                type: type,
                addressViewModel: displayAddressViewModel
            ),
            votes: votesString ?? ""
        )

        return .grouped(.init(
            id: address,
            model: model,
            cells: cells
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

        let displayAddressViewModel: DisplayAddressViewModel

        if let displayName = identites[voter.accountId]?.displayName {
            let displayAddress = DisplayAddress(address: address, username: displayName)
            displayAddressViewModel = displayAddressFactory.createViewModel(from: displayAddress)
        } else {
            displayAddressViewModel = displayAddressFactory.createViewModel(from: address)
        }

        let amountInPlank: BigUInt
        let votes: BigUInt

        switch type {
        case .ayes:
            amountInPlank = voter.vote.ayeBalance
            votes = voter.vote.ayes
        case .nays:
            amountInPlank = voter.vote.nayBalance
            votes = voter.vote.nays
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
        metadata: GovernanceDelegateMetadataRemote?
    ) -> DelegateSingleVoteCollectionViewCell.Model? {
        let address = delegation.delegator

        guard let accountId = try? address.toAccountId() else {
            return nil
        }

        let displayAddressViewModel: DisplayAddressViewModel

        if let displayName = identites[accountId]?.displayName {
            let displayAddress = DisplayAddress(address: address, username: displayName)
            displayAddressViewModel = displayAddressFactory.createViewModel(from: displayAddress)
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

        let type: GovernanceDelegateTypeView.Model? = metadata.map {
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
