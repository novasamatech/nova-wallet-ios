import Foundation
import Foundation_iOS

extension SubtensorUnstakeSetupPresenter: SubtensorUnstakeSetupPresenterProtocol {
    func setup() {
        provideAmountInputViewModel()
        provideAssetViewModel()
        provideViewModel()

        interactor.setup()
        interactor.loadExistentialDeposit()

        guard !isRoot else {
            return
        }

        interactor.loadSubnetsInfo(for: netuid)

        interactor.loadCatalogue()
        interactor.loadSubnetLogos()
        interactor.loadNovaFeeRate()
        interactor.loadCostBasis(for: netuid)
    }

    func didAppear() {
        guard isConfirmationShown else {
            return
        }

        isConfirmationShown = false
        forceQuoteRefresh()
    }

    func selectValidator() {
        loadValidatorsIfNeeded()

        guard let group, group.positions.count > 1 else {
            showValidatorInfo()
            return
        }

        validatorPicker = wireframe.showTargetSelection(
            from: view,
            content: createValidatorPickerContent(for: group),
            delegate: self,
            context: group.positions.map(\.hotkey) as NSArray
        )
    }

    func showValidatorInfo() {
        guard let anchorHotkey, let target else {
            return
        }

        wireframe.showValidatorInfo(
            from: view,
            target: target,
            hotkey: anchorHotkey,
            detail: validatorItems[anchorHotkey]
        )
    }

    func showSwapRateInfo() {
        guard !isRoot, let novaFeeRate = quoteFlow.freshQuote?.novaFeeRate ?? novaFeeRate else {
            return
        }

        let subnetName = SubtensorSubnetNaming.titleWithSymbol(for: netuid, in: catalogue, locale: selectedLocale)

        wireframe.showSubtensorInfo(.swapRate(.sell, subnetName: subnetName, novaFeeRate: novaFeeRate), from: view)
    }

    func showAvgBuyPriceInfo() {
        guard !isRoot else {
            return
        }

        let sheet = SubtensorInfoSheet.avgBuyPrice(
            symbol: SubtensorSubnetNaming.symbol(for: netuid, in: catalogue),
            subnetName: SubtensorSubnetNaming.titleWithSymbol(for: netuid, in: catalogue, locale: selectedLocale)
        )

        wireframe.showSubtensorInfo(sheet, from: view)
    }

    func proceed() {
        loadValidatorsIfNeeded()

        let amount = inputAmount()

        guard
            let amount, amount > 0,
            let basis, basis.available > 0,
            target != nil,
            holdRemainingBlocks(for: amount) == nil else {
            return
        }

        if amount != requestedAmount() {
            provideAmountInputViewModel()
        }

        let dependencies = createValidationDependencies(amount: amount)
        let model = createConfirmModel(for: dependencies)

        dataValidationFactory.validateUnstake(for: dependencies, locale: selectedLocale) { [weak self] in
            guard let self else {
                return
            }

            view?.didStopLoading()

            guard var model else {
                return
            }

            model.acknowledgedQuote = acknowledgedQuote(for: dependencies.quoteContext)
            trackInitiated(for: model)
            isConfirmationShown = true
            wireframe.showConfirmation(from: view, model: model)
        }
    }
}

extension SubtensorUnstakeSetupPresenter {
    func createValidationDependencies(amount: Balance) -> SubtensorUnstakeValidatingDependencies {
        let plan = plan(for: amount)
        let positions = Dictionary((basis?.positions ?? []).map { ($0.hotkey, $0.alpha) }) { first, _ in first }

        return SubtensorUnstakeValidatingDependencies(
            netuid: netuid,
            accountId: selectedAccount.chainAccount.accountId,
            hotkey: anchorHotkey,
            amount: amount,
            positionAlpha: plan?.amount ?? maxAmount,
            positions: positions,
            plan: plan,
            groupHotkeys: groupHotkeys,
            availability: group?.availability,
            balance: balance,
            fee: fee,
            existentialDeposit: existentialDeposit,
            preflight: preflight,
            holds: holds,
            currentBlock: currentBlock,
            assetDisplayInfo: inputDisplayInfo,
            syncFailed: isPositionsSyncFailed,
            onFeeRefresh: { [weak self] in
                self?.refreshFee()
            },
            onPreflightRefresh: { [weak self] in
                self?.refreshPreflight()
            },
            onPositionsRefresh: { [weak self] in
                self?.interactor.refreshPositions()
            },
            onGroupHotkeysRefresh: { [weak self] in
                self?.loadGroupHotkeys()
            },
            onUnstakeAll: createUnstakeAllOffer(),
            quoteContext: createQuoteContext(),
            analytics: createValidationReporter()
        )
    }

    func createUnstakeAllOffer() -> (() -> Void)? {
        guard let basis, basis.canExitAll else {
            return nil
        }

        return { [weak self] in
            self?.selectMax()
        }
    }

    func createConfirmModel(for dependencies: SubtensorUnstakeValidatingDependencies) -> SubtensorConfirmModel? {
        guard
            let target,
            let plan = dependencies.plan,
            let groupHotkeys = dependencies.groupHotkeys,
            let hotkey = Set(plan.hotkeys).count == 1 ? plan.hotkeys.first : anchorHotkey,
            let validator = createConfirmValidator(for: hotkey) else {
            return nil
        }

        return SubtensorConfirmModel(
            origin: isRoot ? .unstake : .sell,
            account: selectedAccount,
            target: target,
            validator: validator,
            mode: .unstake(SubtensorUnstakeModel(
                netuid: netuid,
                plan: plan,
                groupHotkeys: groupHotkeys,
                validators: plan.hotkeys.reduce(into: [:]) { $0[$1] = createConfirmValidator(for: $1) }
            )),
            tolerance: isRoot ? nil : slippage,
            acknowledgedQuote: acknowledgedQuote(for: dependencies.quoteContext),
            hasLockedStake: hasLockedStake
        )
    }
}

extension SubtensorUnstakeSetupPresenter {
    var heldHotkeys: Set<AccountId> {
        guard isRoot, let group, let holds, let currentBlock else {
            return []
        }

        let head = UInt64(currentBlock)

        return Set(group.positions.map(\.hotkey).filter { (holds[$0]?.remainingBlocks(at: head) ?? 0) > 0 })
    }

    var isLegCapped: Bool {
        guard currentSelection == .all, let group else {
            return false
        }

        return SubtensorGroupUnstakeBasis.isLegCapped(group, excluding: heldHotkeys)
    }

    var currentSelection: SubtensorUnstakeSelection? {
        group.map { SubtensorUnstakeSelection.resolve(selection, in: $0, excluding: heldHotkeys) }
    }

    var anchorHotkey: AccountId? {
        guard let group else {
            return nil
        }

        let held = heldHotkeys

        return currentSelection?.hotkey ?? group.positions.first { !held.contains($0.hotkey) }?.hotkey ??
            group.primaryHotkey
    }

    func validatorName(for hotkey: AccountId) -> String? {
        validatorItems[hotkey]?.name
    }

    func createValidatorPickerContent(for group: SubtensorPortfolioGroup) -> CollatorStakingTargetPickerContent {
        let hotkeys = group.positions.map(\.hotkey)
        let held = heldHotkeys
        let names = hotkeys.reduce(into: [AccountId: String]()) { $0[$1] = validatorName(for: $1) }
        let hasAllAction = SubtensorUnstakeSelection.canSellAll(in: group, excluding: held)
        let pickerFactory = SubtensorValidatorPickerViewModelFactory(chainFormat: chainAsset.chain.chainFormat)

        return CollatorStakingTargetPickerContent(
            title: pickerFactory.createTitle(),
            viewModels: pickerFactory.createViewModels(
                for: group.positions,
                names: names,
                disabled: held,
                displayInfo: inputDisplayInfo
            ),
            action: hasAllAction ? pickerFactory.createAllValidatorsAction() : nil,
            selectedIndex: currentSelection?.hotkey.flatMap { hotkeys.firstIndex(of: $0) } ?? NSNotFound
        )
    }

    func refreshValidatorPicker() {
        guard
            let picker = validatorPicker,
            picker.isViewLoaded,
            let group,
            (picker.context as? [AccountId]) == group.positions.map(\.hotkey) else {
            return
        }

        picker.viewModels = createValidatorPickerContent(for: group).viewModels
        picker.reload()
    }

    func createConfirmValidator(for hotkey: AccountId) -> SubtensorConfirmValidator? {
        guard let address = try? hotkey.toAddress(using: chainAsset.chain.chainFormat) else {
            return nil
        }

        return SubtensorConfirmValidator(
            hotkey: hotkey,
            display: DisplayAddress(address: address, username: validatorName(for: hotkey) ?? ""),
            annualRate: nil
        )
    }
}

extension SubtensorUnstakeSetupPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let hotkeys = context as? [AccountId], index < hotkeys.count else {
            return
        }

        let hotkey = hotkeys[index]

        guard !heldHotkeys.contains(hotkey) else {
            presentHold(for: hotkey)
            return
        }

        applySelection(.validator(hotkey))
    }

    func modalPickerDidSelectAction(context _: AnyObject?) {
        applySelection(.all)
    }

    private func applySelection(_ newSelection: SubtensorUnstakeSelection) {
        guard newSelection != currentSelection else {
            return
        }

        let previousPlan = feePlan()

        selection = newSelection
        inputResult = nil

        provideAmountInputViewModel()
        applyBasisChange(from: previousPlan)
        provideViewModel()
    }

    private func presentHold(for hotkey: AccountId) {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
        let interval = TimeInterval(holds?[hotkey]?.interval ?? 0)
        let duration = blockTime.map {
            (interval * $0.timeInterval).localizedDaysHoursOrFallbackMinutes(for: selectedLocale)
        } ?? ""

        wireframe.present(
            message: strings.stakingSubtensorUiPositionHoldMessageFormat(duration),
            title: strings.stakingSubtensorUiPositionHoldTitle(),
            closeAction: strings.commonClose(),
            from: view
        )
    }
}

extension SubtensorUnstakeSetupPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideAmountInputViewModel()
            provideAssetViewModel()
            provideViewModel()
        }
    }
}
