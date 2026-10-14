import Foundation

extension SubtensorConfirmPresenter {
    func createUnstakeOperation(
        for unstakeModel: SubtensorUnstakeModel,
        limitPrice: Balance?,
        quotedTaoOut: Balance?
    ) -> SubtensorStakingOperation? {
        guard !model.target.isRoot else {
            let amount = SubtensorAmountPolicy.rootUnstakeAmount(
                requested: unstakeModel.amount,
                transferable: balance?.transferable,
                networkFee: fee?.amountForCurrentAccount,
                existentialDeposit: existentialDeposit
            )

            return unstakeModel.exitHotkeys.map { .rootUnstakeAll(hotkeys: $0) } ??
                .rootUnstake(hotkey: unstakeModel.hotkey, amount: amount)
        }

        guard let limitPrice, let quotedTaoOut else {
            return nil
        }

        guard let exitHotkeys = unstakeModel.exitHotkeys else {
            return .subnetSell(
                hotkey: unstakeModel.hotkey,
                netuid: unstakeModel.netuid,
                alpha: unstakeModel.amount,
                limitPrice: limitPrice,
                quotedTaoOut: quotedTaoOut
            )
        }

        return .subnetSellAll(
            hotkeys: exitHotkeys,
            netuid: unstakeModel.netuid,
            limitPrice: limitPrice,
            quotedTaoOut: quotedTaoOut
        )
    }

    func createStakeChange(removing unstakeModel: SubtensorUnstakeModel) -> SubtensorConfirmStakeChange? {
        guard model.target.isRoot, !isPositionsSyncFailed, let group = liveGroup() else {
            return nil
        }

        let after = unstakeModel.isFullUnstake ? 0 : group.totalAlpha.subtractOrZero(unstakeModel.amount)

        return SubtensorConfirmStakeChange(before: group.totalAlpha, after: after)
    }

    func refreshHolds() {
        guard
            model.target.isRoot,
            case let .unstake(unstakeModel) = model.mode,
            let exitHotkeys = unstakeModel.exitHotkeys, exitHotkeys.count > 1 else {
            return
        }

        interactor.loadRootHolds(for: exitHotkeys)
    }

    func didReceiveRootHolds(_ holds: [AccountId: SubtensorRootHold]) {
        self.holds = holds
    }

    func isExitGroupUnchanged() -> Bool {
        guard case let .unstake(unstakeModel) = model.mode, unstakeModel.isFullUnstake else {
            return true
        }

        return SubtensorConfirmTapRule.verifiedExitHotkeys(for: unstakeModel, in: positionsState) != nil
    }

    func presentGroupChanged() {
        guard let view else {
            return
        }

        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        wireframe.present(
            message: nil,
            title: strings.stakingSubtensorAlertStaleTitle(),
            closeAction: strings.commonClose(),
            from: view
        )
    }

    func emptiesPosition(_ operation: SubtensorStakingOperation, group: SubtensorPortfolioGroup?) -> Bool {
        switch operation {
        case let .rootUnstakeAll(hotkeys), let .subnetSellAll(hotkeys, _, _, _):
            let groupHotkeys = Set(group?.positions.map(\.hotkey) ?? [])
            return groupHotkeys.isSubset(of: Set(hotkeys))
        case .rootStake, .rootUnstake, .rootClaim, .subnetBuy, .subnetSell:
            return false
        }
    }

    func confirmUnstake(_ unstakeModel: SubtensorUnstakeModel) {
        let group = liveGroup()
        let primaryAlpha = group?.positions.first { $0.hotkey == unstakeModel.hotkey }?.stakeAlpha

        var dependencies = SubtensorUnstakeValidatingDep(
            netuid: unstakeModel.netuid,
            accountId: model.account.chainAccount.accountId,
            amount: unstakeModel.isFullUnstake ? group?.totalAlpha : unstakeModel.amount,
            positionAlpha: unstakeModel.isFullUnstake ? group?.totalAlpha : primaryAlpha,
            availability: group?.availability,
            exitHotkeys: unstakeModel.exitHotkeys,
            balance: balance,
            fee: fee,
            existentialDeposit: existentialDeposit,
            preflight: preflight,
            holds: holds,
            currentBlock: currentBlock,
            blockTime: SubtensorStakingFlowConstants.blockTimeMillis,
            assetDisplayInfo: viewModelFactory.amountDisplayInfo(for: model.target, catalogue: catalogue),
            syncFailed: isPositionsSyncFailed || positionsState == nil,
            onFeeRefresh: { [weak self] in
                self?.refreshFee()
            },
            onPreflightRefresh: { [weak self] in
                self?.refreshPreflight()
            },
            onPositionsRefresh: { [weak self] in
                self?.interactor.refreshPositions()
            }
        )

        dependencies.quoteContext = createQuoteContext()

        validateUnstake(
            for: dependencies,
            dataValidationFactory: dataValidationFactory,
            selectedLocale: selectedLocale
        ) { [weak self] in
            self?.handOffAtTap()
        }
    }
}
