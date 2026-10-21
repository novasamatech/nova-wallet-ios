import Foundation

extension SubtensorStakeSetupPresenter: SubtensorSubnetSelectDelegate {
    func didSelectStakeTarget(
        _ target: SubtensorStakeTarget,
        validator: SubtensorValidatorDirectoryItem?,
        recommendedHotkey: AccountId?
    ) {
        guard !mode.isLocked else {
            return
        }

        self.recommendedHotkey = recommendedHotkey

        quickPickVisit?.replaceManually()
        interactor.cancelQuickPickSnapshot()

        switch target {
        case .root:
            mode = .rootDetails
        case .subnet:
            mode = .subnetPick(target: target, validator: validator)
        }

        startMode()
    }
}

extension SubtensorStakeSetupPresenter: SubtensorValidatorSelectDelegate {
    func didSelectValidator(_ validator: SubtensorValidatorDirectoryItem, for target: SubtensorStakeTarget) {
        if mode.isLocked, target.netuid == mode.netuid {
            validatorItems[validator.hotkey] = validator

            let held = heldPositions().first { $0.hotkey == validator.hotkey }
            applyStakeMore(
                held ?? SubtensorPosition(
                    hotkey: validator.hotkey,
                    netuid: target.netuid,
                    stakeAlpha: 0,
                    isRegistered: !validator.isInactive
                )
            )
            return
        }

        guard !mode.isLocked, target.subnetRef == subnetRef else {
            return
        }

        applyValidator(validator)
    }

    func selectValidator() {
        guard !mode.isLocked else {
            showStakeMorePicker()
            return
        }

        guard let target else {
            return
        }

        showValidatorList(for: target)
    }
}

extension SubtensorStakeSetupPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let positions = context as? [SubtensorPosition], index < positions.count else {
            return
        }

        applyStakeMore(positions[index])
    }

    func modalPickerDidSelectAction(context _: AnyObject?) {
        guard let target else {
            return
        }

        showValidatorList(for: target)
    }
}

extension SubtensorStakeSetupPresenter {
    func didReceiveHeldValidators(_ validators: [AccountId: SubtensorValidatorDirectoryItem], hotkeys: [AccountId]) {
        guard hotkeys == heldValidatorsRequest else {
            return
        }

        validatorItems.merge(validators) { _, new in new }
        heldValidatorsResolved = hotkeys

        resolveLockedValidator()
        refreshValidatorPicker()
        provideViewModel()
    }

    func didFailHeldValidators(for hotkeys: [AccountId]) {
        guard hotkeys == heldValidatorsRequest else {
            return
        }

        heldValidatorsRequest = nil
        heldValidatorsResolved = nil

        resolveLockedValidator()
        provideViewModel()
    }

    func refreshValidatorPicker() {
        guard
            let picker = validatorPicker,
            picker.isViewLoaded,
            let positions = picker.context as? [SubtensorPosition] else {
            return
        }

        picker.viewModels = createStakeMorePickerViewModels(for: positions)
        picker.reload()
    }

    func resolveLockedValidator() {
        guard let hotkey = mode.lockedHotkey, let subnetRef else {
            return
        }

        if let item = validatorItems[hotkey] {
            isLockedValidatorPending = false
            validatorState = .selected(SubtensorStakeSetupValidator(hotkey: hotkey, name: item.name))
            return
        }

        isLockedValidatorPending = true

        let isBatchPending = heldValidatorsRequest != heldValidatorsResolved &&
            heldValidatorsRequest?.contains(hotkey) == true

        guard !isBatchPending, lockedValidatorRequest != hotkey else {
            return
        }

        lockedValidatorRequest = hotkey
        interactor.loadLockedValidator(hotkey, on: subnetRef)
    }

    var selectedValidatorItem: SubtensorValidatorDirectoryItem? {
        guard let hotkey = mode.lockedHotkey else {
            return validatorItem
        }

        return validatorItems[hotkey]
    }

    func loadHeldValidatorsIfNeeded() {
        let hotkeys = heldPositions().map(\.hotkey)

        guard mode.isLocked, let subnetRef, !hotkeys.isEmpty, hotkeys != heldValidatorsRequest else {
            return
        }

        heldValidatorsRequest = hotkeys
        interactor.loadHeldValidators(hotkeys, on: subnetRef)
    }
}

private extension SubtensorStakeSetupPresenter {
    func heldPositions() -> [SubtensorPosition] {
        guard let netuid = mode.netuid, let positionsState else {
            return []
        }

        return SubtensorPortfolioBuilder.build(state: positionsState).group(netuid: netuid)?.positions ?? []
    }

    func showValidatorList(for target: SubtensorStakeTarget) {
        wireframe.showValidatorSelection(
            from: view,
            target: target,
            selectedHotkey: validatorState.validator?.hotkey,
            analytics: SubtensorValidatorSelectAnalytics(recommendedHotkey: recommendedHotkey, abandonTracker: nil),
            delegate: self
        )
    }

    func showStakeMorePicker() {
        guard target != nil else {
            return
        }

        loadHeldValidatorsIfNeeded()

        let positions = heldPositions()
        let pickerFactory = SubtensorValidatorPickerViewModelFactory(chainFormat: chainAsset.chain.chainFormat)

        let content = CollatorStakingTargetPickerContent(
            title: pickerFactory.createTitle(),
            viewModels: createStakeMorePickerViewModels(for: positions),
            action: pickerFactory.createNewValidatorAction(),
            selectedIndex: positions.firstIndex { $0.hotkey == mode.lockedHotkey } ?? NSNotFound
        )

        validatorPicker = wireframe.showTargetSelection(
            from: view,
            content: content,
            delegate: self,
            context: positions as NSArray,
            keeping: validatorPicker
        )
    }

    func createStakeMorePickerViewModels(for positions: [SubtensorPosition]) -> [AccountDetailsPickerViewModel] {
        guard let netuid = mode.netuid else {
            return []
        }

        let names = positions.reduce(into: [AccountId: String]()) { names, position in
            names[position.hotkey] = validatorItems[position.hotkey]?.name
        }

        return SubtensorValidatorPickerViewModelFactory(chainFormat: chainAsset.chain.chainFormat).createViewModels(
            for: positions,
            names: names,
            disabled: [],
            displayInfo: chainAsset.assetDisplayInfo.subtensorAlpha(netuid: netuid, catalogue: catalogue)
        )
    }

    func applyStakeMore(_ position: SubtensorPosition) {
        guard position.hotkey != mode.lockedHotkey else {
            return
        }

        switch mode {
        case .addStake:
            mode = .addStake(position: position)
        case .buyMore:
            mode = .buyMore(position: position)
        case .quickPick, .rootDetails, .subnetPick:
            return
        }

        validatorState = .selected(
            SubtensorStakeSetupValidator(hotkey: position.hotkey, name: validatorItems[position.hotkey]?.name)
        )
        preflight = nil
        quoteFlow = SubtensorQuoteFlowModel()
        isQuoteFailed = false
        tradesUnavailable = false

        applyTargetIfReady()
    }
}

extension SubtensorStakeSetupPresenter: RampFlowManaging, RampDelegate {
    func rampDidComplete(action: RampActionType, chainAsset _: ChainAsset) {
        wireframe.popTopControllers(from: view) { [weak self] in
            guard let self else {
                return
            }

            wireframe.presentRampDidComplete(view: view, action: action, locale: selectedLocale)
        }
    }
}

extension SubtensorStakeSetupPresenter {
    func createValidationDependencies(for target: SubtensorStakeTarget) -> SubtensorStakeValidatingDependencies {
        SubtensorStakeValidatingDependencies(
            amount: inputAmount(),
            balance: balance,
            fee: fee,
            preflight: preflight,
            netuid: target.netuid,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            onFeeRefresh: { [weak self] in
                self?.refreshFee()
            },
            onPreflightRefresh: { [weak self] in
                self?.refreshPreflight()
            },
            quoteContext: createQuoteContext(),
            isValidatorInactive: selectedValidatorItem?.isInactive == true,
            analytics: createValidationReporter(for: target)
        )
    }

    func createConfirmModel(for dependencies: SubtensorStakeValidatingDependencies) -> SubtensorConfirmModel? {
        guard
            let target,
            let validator = validatorState.validator,
            let amount = dependencies.amount,
            let address = try? validator.hotkey.toAddress(using: chainAsset.chain.chainFormat) else {
            return nil
        }

        return SubtensorConfirmModel(
            origin: mode.origin,
            account: selectedAccount,
            target: target,
            validator: SubtensorConfirmValidator(
                hotkey: validator.hotkey,
                display: DisplayAddress(address: address, username: validator.name ?? ""),
                annualRate: validatorAnnualRate()
            ),
            mode: .stake(amount: amount),
            tolerance: target.isRoot ? nil : slippage,
            acknowledgedQuote: acknowledgedQuote(for: dependencies.quoteContext)
        )
    }
}

extension SubtensorStakeSetupPresenter: SubtensorQuoteHandling {
    var isRoot: Bool { target?.isRoot == true }
    var retryView: ControllerBackedProtocol? { view }
    var retryWireframe: AlertPresentable & FeeRetryable & CommonRetryable { wireframe }
    var quoteInteractor: SubtensorBaseInteractorInputProtocol { interactor }
    var loadingView: LoadableViewProtocol? { view }

    var alphaDisplayInfo: AssetBalanceDisplayInfo {
        guard let target else {
            return chainAsset.assetDisplayInfo
        }

        return chainAsset.assetDisplayInfo.subtensorAlpha(netuid: target.netuid, catalogue: catalogue)
    }
}
