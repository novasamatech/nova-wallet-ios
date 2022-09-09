import Foundation

extension ParaStkYieldBoostSetupPresenter: ParaStkYieldBoostSetupPresenterProtocol {
    func setup() {
        interactor.setup()

        setupCollatorIfNeeded()
        refreshYieldBoostParamsIfNeeded()

        provideViewModels()
    }

    func switchRewardsOption(to isYieldBoosted: Bool) {
        guard isYieldBoostSelected != isYieldBoosted else {
            return
        }

        updateYieldBoostSelected(isYieldBoosted)

        provideRewardOptionSelectionViewModel()

        if isYieldBoostSelected {
            provideYieldBoostSpecificViewModels()
        }

        updateHasChanges()
    }

    func updateThresholdAmount(_ newValue: Decimal?) {
        let newThresholdInput = newValue.map { AmountInputResult.absolute($0) }

        updateThresholdInput(newThresholdInput)

        provideAssetViewModel()
        updateHasChanges()
    }

    func selectThresholdAmountPercentage(_ percentage: Float) {
        let newThresholdInput = AmountInputResult.rate(Decimal(Double(percentage)))

        updateThresholdInput(newThresholdInput)

        provideThresholdInputViewModel()
        provideAssetViewModel()
        updateHasChanges()
    }

    func selectCollator() {
        guard let delegator = delegator else {
            return
        }

        let delegations = delegator.delegations.sorted { $0.amount > $1.amount }
        let disabledCollators = Self.disabledCollatorsForYieldBoost(from: scheduledRequests ?? [])

        guard delegations.count > disabledCollators.count else {
            return
        }

        let accountDetailsViewModels = accountDetailsViewModelFactory.createViewModels(
            from: delegations,
            identities: delegationIdentities,
            disabled: disabledCollators
        )

        let selectedIndex = delegations.firstIndex { $0.owner == selectedCollator } ?? NSNotFound

        wireframe.showDelegationSelection(
            from: view,
            viewModels: accountDetailsViewModels,
            selectedIndex: selectedIndex,
            delegate: self,
            context: delegations as NSArray
        )
    }

    func proceed() {
        // TODO: Implement transition to confirmation
    }
}
