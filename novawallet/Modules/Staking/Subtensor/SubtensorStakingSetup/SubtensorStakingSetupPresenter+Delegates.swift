import Foundation

extension SubtensorStakingSetupPresenter: SubtensorSubnetSelectDelegate {
    func didSelectStakeTarget(_ target: SubtensorStakeTarget, validator: SubtensorValidatorDirectoryItem?) {
        guard !mode.isLocked else {
            return
        }

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
        guard !mode.isLocked, target.netuid == self.target?.netuid else {
            return
        }

        applyValidator(hotkey: validator.hotkey, name: validator.name)
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
            existentialDeposit: existentialDeposit,
            preflight: preflight,
            netuid: target.netuid,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            onFeeRefresh: { [weak self] in
                self?.refreshFee(resetting: false)
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

        if case .addStake = mode {
            dependencies.rootHoldCheck = SubtensorRootHoldCheck(
                currentBlock: currentBlock,
                blockTime: SubtensorStakingFlowConstants.blockTimeMillis
            )
        }

        return dependencies
    }

    func createConfirmModel() -> SubtensorStakingConfirmModel? {
        guard
            let target,
            let validator = validatorState.validator,
            let amount = inputAmount(),
            let address = try? validator.hotkey.toAddress(using: chainAsset.chain.chainFormat) else {
            return nil
        }

        return SubtensorStakingConfirmModel(
            origin: mode.origin,
            account: selectedAccount,
            target: target,
            validator: SubtensorConfirmValidator(
                hotkey: validator.hotkey,
                display: DisplayAddress(address: address, username: validator.name ?? ""),
                annualRate: target.isRoot ? rootRate : nil
            ),
            amount: amount,
            tolerance: target.isRoot ? nil : slippage,
            acknowledgedQuote: target.isRoot ? nil : quoteFlow.freshQuote
        )
    }
}
