import Foundation

extension ParaStkUnstakePresenter: CollatorStkPartialUnstakeSetupPresenterProtocol {
    func setup() {
        let optCollatorId = selectInitialCollator()

        provideAmountInputViewModel()

        provideCollatorViewModel()
        provideAssetViewModel()
        provideMinStakeViewModel()
        provideTransferableViewModel()
        provideHints()
        provideFeeViewModel()

        interactor.setup()

        if let collatorId = optCollatorId {
            interactor.applyCollator(with: collatorId)
        }

        refreshFee()
    }

    func selectCollator() {
        guard
            let delegator = delegator,
            let disabledCollators = scheduledRequests?.map(\.collatorId) else {
            return
        }

        let delegations = delegator.delegations.sorted { $0.amount > $1.amount }

        let accountDetailsViewModels = accountDetailsViewModelFactory.createViewModelsFromBonds(
            delegations,
            identities: delegationIdentities,
            disabled: Set(disabledCollators)
        )

        let collatorId = try? collatorDisplayAddress?.address.toAccountId()

        let selectedIndex = delegations.firstIndex { $0.owner == collatorId } ?? NSNotFound

        wireframe.showUndelegationSelection(
            from: view,
            viewModels: accountDetailsViewModels,
            selectedIndex: selectedIndex,
            delegate: self,
            context: delegations as NSArray
        )
    }

    func updateAmount(_ newValue: Decimal?) {
        let newInputResult = newValue.map { AmountInputResult.absolute($0) }
        updateInputResult(newInputResult)

        refreshFee()
        provideAssetViewModel()
    }

    func selectAmountPercentage(_ percentage: Float) {
        let newInputResult = AmountInputResult.rate(Decimal(Double(percentage)))
        updateInputResult(newInputResult)

        provideAmountInputViewModel()

        refreshFee()
        provideAssetViewModel()
    }

    private func createValidationRunner() -> DataValidationRunner {
        let assetInfo = chainAsset.assetDisplayInfo
        let inputAmount = inputResult?.absoluteValue(from: decimalStakingAmount())
        let optCollatorId = try? collatorDisplayAddress?.address.toAccountId()
        let stakedAmount = stakingAmountInPlank()

        let minDelegationParams = ParaStkMinDelegationParams(
            minDelegation: minDelegationAmount,
            minDelegatorStake: minTechStake,
            delegationsCount: delegator?.delegations.count
        )

        return DataValidationRunner(validators: [
            dataValidatingFactory.has(
                fee: fee,
                locale: selectedLocale,
                onError: { [weak self] in self?.refreshFee() }
            ),
            dataValidatingFactory.canPayFeeInPlank(
                balance: balance?.transferable,
                fee: fee,
                asset: assetInfo,
                locale: selectedLocale
            ),
            dataValidatingFactory.canUnstake(
                amount: inputAmount,
                staked: stakedAmount,
                from: optCollatorId,
                scheduledRequests: scheduledRequests,
                locale: selectedLocale
            ),
            dataValidatingFactory.willRemainTopStaker(
                unstakingAmount: inputAmount,
                staked: stakedAmount,
                collator: collatorMetadata,
                minDelegationParams: minDelegationParams,
                locale: selectedLocale
            ),
            dataValidatingFactory.shouldUnstakeAll(
                unstakingAmount: inputAmount,
                staked: stakedAmount,
                minDelegationParams: minDelegationParams,
                locale: selectedLocale
            )
        ])
    }

    func proceed() {
        let validationRunner = createValidationRunner()
        validationRunner.runValidation { [weak self] in
            guard let collator = self?.collatorDisplayAddress, let callWrapper = self?.createCallWrapper() else {
                return
            }

            self?.wireframe.showUnstakingConfirm(from: self?.view, collator: collator, callWrapper: callWrapper)
        }
    }
}
