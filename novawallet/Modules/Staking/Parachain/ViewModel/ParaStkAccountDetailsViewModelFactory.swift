import Foundation
import Foundation_iOS

extension CollatorStakingAccountViewModelFactoryProtocol {
    func createCollator(
        from collatorAddress: DisplayAddress,
        delegator: ParachainStaking.Delegator?,
        locale: Locale
    ) -> AccountDetailsSelectionViewModel {
        let stakedAmount: Balance? = if let collator = try? collatorAddress.address.toAccountId() {
            delegator?.delegations.first(where: { $0.owner == collator })?.amount
        } else {
            nil
        }

        return createCollator(
            from: collatorAddress,
            stakedAmount: stakedAmount,
            locale: locale
        )
    }

    func createViewModelsFromBonds(
        _ bonds: [ParachainStaking.Bond],
        identities: [AccountId: AccountIdentity]?,
        disabled: Set<AccountId>
    ) -> [LocalizableResource<SelectableViewModel<AccountDetailsSelectionViewModel>>] {
        let stakedCollators = bonds.map { bond in
            CollatorStakingAccountViewModelFactory.StakedCollator(
                collator: bond.owner,
                amount: bond.amount
            )
        }

        return createViewModels(
            from: stakedCollators,
            identities: identities,
            disabled: disabled
        )
    }

    func createParachainUnstakingViewModels(
        from scheduledRequests: [ParachainStaking.DelegatorScheduledRequest],
        identities: [AccountId: AccountIdentity]?
    ) -> [LocalizableResource<AccountDetailsSelectionViewModel>] {
        let unstakedCollators = scheduledRequests.map { scheduledRequest in
            CollatorStakingAccountViewModelFactory.StakedCollator(
                collator: scheduledRequest.collatorId,
                amount: scheduledRequest.unstakingAmount
            )
        }

        return createUnstakingViewModels(
            from: unstakedCollators,
            identities: identities
        )
    }
}
