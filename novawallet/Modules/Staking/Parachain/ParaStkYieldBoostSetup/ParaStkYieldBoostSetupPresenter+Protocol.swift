import Foundation

extension ParaStkYieldBoostSetupPresenter: ParaStkYieldBoostSetupPresenterProtocol {
    func setup() {
        interactor.setup()

        setupCollatorIfNeeded()
        provideViewModels()
        refreshYieldBoostParamsIfNeeded()

        if isYieldBoostSelected {
            refreshTaskExecutionTime()
        }

        refreshFeeIfNeeded()
    }

    func switchRewardsOption(to isYieldBoosted: Bool) {
        guard isYieldBoostSelected != isYieldBoosted else {
            return
        }

        updateYieldBoostSelected(isYieldBoosted)

        provideRewardOptionSelectionViewModel()

        if isYieldBoostSelected {
            provideYieldBoostSpecificViewModels()
            refreshTaskExecutionTime()
        }

        updateHasChanges()

        refreshFeeIfNeeded()
    }

    func updateThresholdAmount(_ newValue: Decimal?) {
        let newThresholdInput = newValue.map { AmountInputResult.absolute($0) }

        updateThresholdInput(newThresholdInput)

        provideAssetViewModel()
        updateHasChanges()

        refreshExtrinsicFee()
    }

    func selectThresholdAmountPercentage(_ percentage: Float) {
        let newThresholdInput = AmountInputResult.rate(Decimal(Double(percentage)))

        updateThresholdInput(newThresholdInput)

        provideThresholdInputViewModel()
        provideAssetViewModel()
        updateHasChanges()

        refreshExtrinsicFee()
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
        if isYieldBoostSelected {
            proceedWithYieldBoost()
        } else {
            proceedWithoutYieldBoost()
        }
    }

    private func createYieldBoostValidationRunner(
        for assetDisplayInfo: AssetBalanceDisplayInfo,
        threshold: Decimal?
    ) -> DataValidationRunnerProtocol {
        DataValidationRunner(validators: [
            dataValidatingFactory.hasInPlank(
                fee: extrinsicFee,
                locale: selectedLocale,
                precision: assetDisplayInfo.assetPrecision,
                onError: { [weak self] in
                    self?.refreshFeeIfNeeded()
                }
            ),
            dataValidatingFactory.hasInPlank(
                fee: taskExecutionFee,
                locale: selectedLocale,
                precision: assetDisplayInfo.assetPrecision,
                onError: { [weak self] in
                    self?.interactor.estimateTaskExecutionFee()
                }
            ),
            dataValidatingFactory.hasExecutionTime(
                taskExecutionTime,
                locale: selectedLocale,
                errorClosure: { [weak self] in
                    self?.refreshTaskExecutionTime()
                }
            ),
            dataValidatingFactory.enoughBalanceForThreshold(
                threshold,
                balance: balance?.transferable,
                extrinsicFee: extrinsicFee,
                assetInfo: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            ),
            dataValidatingFactory.enoughBalanceForExecutionFee(
                taskExecutionFee,
                balance: balance?.transferable,
                extrinsicFee: extrinsicFee,
                assetInfo: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            ),
            dataValidatingFactory.cancelForOtherCollatorsExcept(
                selectedCollatorId: selectedCollator,
                tasks: yieldBoostTasks,
                locale: selectedLocale
            )
        ])
    }

    private func proceedWithYieldBoost() {
        let assetDisplayInfo = chainAsset.assetDisplayInfo
        let optTreshold = thresholdInput?.absoluteValue(from: maxSpendingAmount()) ??
            selectedRemoteBoostThreshold()

        let runner = createYieldBoostValidationRunner(for: assetDisplayInfo, threshold: optTreshold)

        runner.runValidation { [weak self] in
            guard
                let selectedCollator = self?.selectedCollator,
                let period = self?.yieldBoostParams?.period,
                let executionTime = self?.taskExecutionTime,
                let accountMinimum = optTreshold else {
                return
            }

            let model = ParaStkYieldBoostConfirmModel(
                collator: selectedCollator,
                accountMinimum: accountMinimum,
                period: period,
                executionTime: executionTime,
                collatorIdentity: self?.delegationIdentities?[selectedCollator]
            )

            self?.wireframe.showStartYieldBoostConfirmation(from: self?.view, model: model)
        }
    }

    private func proceedWithoutYieldBoost() {
        let assetDisplayInfo = chainAsset.assetDisplayInfo

        DataValidationRunner(validators: [
            dataValidatingFactory.hasInPlank(
                fee: extrinsicFee,
                locale: selectedLocale,
                precision: assetDisplayInfo.assetPrecision,
                onError: { [weak self] in
                    self?.refreshFeeIfNeeded()
                }
            ),
            dataValidatingFactory.canPayFeeInPlank(
                balance: balance?.transferable,
                fee: extrinsicFee,
                asset: assetDisplayInfo,
                locale: selectedLocale
            ),
            dataValidatingFactory.cancellingTaskExists(
                for: selectedCollator,
                tasks: yieldBoostTasks,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            guard let selectedCollator = self?.selectedCollator else {
                return
            }

            self?.wireframe.showStopYieldBoostConfirmation(
                from: self?.view,
                collatorId: selectedCollator,
                collatorIdentity: self?.delegationIdentities?[selectedCollator]
            )
        }
    }
}
