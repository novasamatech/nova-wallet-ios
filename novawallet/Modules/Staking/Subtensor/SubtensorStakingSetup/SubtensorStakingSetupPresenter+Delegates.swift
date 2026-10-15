import Foundation

extension SubtensorStakingSetupPresenter: SubtensorSubnetSelectDelegate {
    func didSelectStakeTarget(_ target: SubtensorStakeTarget, validator: SubtensorValidatorDirectoryItem?) {
        guard !mode.isLocked else {
            return
        }

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

extension SubtensorStakingSetupPresenter: SubtensorValidatorSelectDelegate {
    func didSelectValidator(_ validator: SubtensorValidatorDirectoryItem, for target: SubtensorStakeTarget) {
        guard !mode.isLocked, target.netuid == self.target?.netuid,
              target.subnetInfo?.networkRegisteredAt == self.target?.subnetInfo?.networkRegisteredAt else {
            return
        }

        applyValidator(validator)
    }
}

extension SubtensorStakingSetupPresenter: RampFlowManaging, RampDelegate {
    func rampDidComplete(action: RampActionType, chainAsset _: ChainAsset) {
        wireframe.popTopControllers(from: view) { [weak self] in
            guard let self else {
                return
            }

            wireframe.presentRampDidComplete(view: view, action: action, locale: selectedLocale)
        }
    }
}

extension SubtensorStakingSetupPresenter: SubtensorStakePresenterValidating {
    func createValidationDependencies(for target: SubtensorStakeTarget) -> SubtensorStakeValidatingDep {
        var dependencies = SubtensorStakeValidatingDep(
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
            }
        )

        if !target.isRoot {
            let latestQuote = quoteFlow.freshQuote

            dependencies.quoteContext = SubtensorQuoteValidatingContext(
                latestQuote: latestQuote,
                acknowledgedLimit: latestQuote?.limitPrice,
                tradesUnavailable: tradesUnavailable,
                onQuoteRefresh: { [weak self] in
                    self?.forceQuoteRefresh()
                }
            )
        }

        return dependencies
    }

    func createConfirmModel() -> SubtensorConfirmModel? {
        guard
            let target,
            let validator = validatorState.validator,
            let amount = inputAmount(),
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
            acknowledgedQuote: target.isRoot ? nil : quoteFlow.freshQuote
        )
    }
}
