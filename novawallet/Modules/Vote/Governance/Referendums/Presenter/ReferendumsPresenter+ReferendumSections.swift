import Foundation

extension ReferendumsPresenter {
    func createReferendumsSections(
        for referendums: [ReferendumLocal],
        accountVotes: ReferendumAccountVotingDistribution?,
        chainInfo: ReferendumsModelFactoryParams.ChainInformation
    ) -> [ReferendumsSection] {
        let params = ReferendumsModelFactoryParams(
            referendums: referendums,
            metadataMapping: referendumsMetadata,
            votes: accountVotes?.votes ?? [:],
            offchainVotes: offchainVoting,
            chainInfo: chainInfo,
            voterName: nil
        )

        return viewModelFactory.createSections(
            params: params,
            genericParams: createGenericParams()
        )
    }

    func createActivitySection(
        chain: ChainModel,
        currentBlock: BlockNumber
    ) -> ReferendumsSection {
        if supportsDelegations {
            activityViewModelFactory.createReferendumsActivitySection(
                chain: chain,
                voting: observableState.voting?.value,
                blockNumber: currentBlock,
                unlockSchedule: unlockSchedule,
                genericParams: createGenericParams()
            )
        } else {
            activityViewModelFactory.createReferendumsActivitySectionWithoutDelegations(
                chain: chain,
                voting: observableState.voting?.value,
                blockNumber: currentBlock,
                unlockSchedule: unlockSchedule,
                genericParams: createGenericParams()
            )
        }
    }

    func createSwipeGovSection() -> ReferendumsSection? {
        guard supportsSwipeGov == true else {
            return nil
        }

        return swipeGovViewModelFactory.createSwipeGovReferendumsSection(
            with: observableState.state.value,
            eligibleReferendums: swipeGovEligibleReferendums ?? [],
            genericParams: createGenericParams()
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
