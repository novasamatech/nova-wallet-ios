import Foundation

extension SubtensorSetupPresenter: SubtensorSubnetSelectDelegate {
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

extension SubtensorSetupPresenter: SubtensorValidatorSelectDelegate {
    func didSelectValidator(_ validator: SubtensorValidatorDirectoryItem, for target: SubtensorStakeTarget) {
        guard !mode.isLocked, target.subnetRef == subnetRef else {
            return
        }

        applyValidator(validator)
    }
}

extension SubtensorSetupPresenter: RampFlowManaging, RampDelegate {
    func rampDidComplete(action: RampActionType, chainAsset _: ChainAsset) {
        wireframe.popTopControllers(from: view) { [weak self] in
            guard let self else {
                return
            }

            wireframe.presentRampDidComplete(view: view, action: action, locale: selectedLocale)
        }
    }
}

extension SubtensorSetupPresenter {
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
            quoteContext: createQuoteContext()
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
