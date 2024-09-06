import Foundation

extension ReferendumsPresenter {
    func creaateReferendumsSections(
        for referendums: [ReferendumLocal],
        accountVotes: ReferendumAccountVotingDistribution?,
        chainInfo: ReferendumsModelFactoryInput.ChainInformation
    ) -> [ReferendumsSection] {
        viewModelFactory.createSections(input: .init(
            referendums: referendums,
            metadataMapping: referendumsMetadata,
            votes: accountVotes?.votes ?? [:],
            offchainVotes: offchainVoting,
            chainInfo: chainInfo,
            locale: selectedLocale,
            voterName: nil
        ))
    }

    func createActivitySection(
        chain: ChainModel,
        currentBlock: BlockNumber
    ) -> ReferendumsSection {
        if supportsDelegations {
            activityViewModelFactory.createReferendumsActivitySection(
                chain: chain,
                voting: voting?.value,
                blockNumber: currentBlock,
                unlockSchedule: unlockSchedule,
                locale: selectedLocale
            )
        } else {
            activityViewModelFactory.createReferendumsActivitySectionWithoutDelegations(
                chain: chain,
                voting: voting?.value,
                blockNumber: currentBlock,
                unlockSchedule: unlockSchedule,
                locale: selectedLocale
            )
        }
    }

    func createTinderGovSection(
        for referendums: [ReferendumLocal],
        accountVotes: ReferendumAccountVotingDistribution?
    ) -> ReferendumsSection? {
        guard supportsTinderGov == true else {
            return nil
        }

        let filter = ReferendumFilter.VoteAvailable(
            referendums: referendums,
            accountVotes: accountVotes
        )

        return tinderGovViewModelFactory.createTinderGovReferendumsSection(
            using: filter,
            locale: selectedLocale
        )
    }

    func filteredReferendumsSections(for referendumsSections: [ReferendumsSection]) -> [ReferendumsSection] {
        if filter != .all {
            viewModelFactory.filteredSections(referendumsSections) {
                filteredReferendums[$0.referendumIndex] != nil
            }
        } else {
            referendumsSections
        }
    }
}
