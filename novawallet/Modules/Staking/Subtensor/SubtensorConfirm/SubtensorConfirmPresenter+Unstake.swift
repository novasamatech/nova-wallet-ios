import Foundation

extension SubtensorConfirmPresenter {
    func createUnstakeOperation(
        for unstakeModel: SubtensorUnstakeModel,
        limitPrice: Balance?,
        quote: SubtensorTradeQuote?
    ) -> SubtensorOperation? {
        guard !model.target.isRoot else {
            let amount = SubtensorAmountPolicy.rootUnstakeAmount(
                requested: unstakeModel.amount,
                transferable: balance?.transferable,
                networkFee: fee?.amountForCurrentAccount,
                existentialDeposit: existentialDeposit
            )

            return unstakeModel.plan.rootOperation(amount: amount)
        }

        guard let limitPrice, let quote else {
            return nil
        }

        return unstakeModel.plan.subnetOperation(
            netuid: unstakeModel.netuid,
            limitPrice: limitPrice,
            quotedTaoOut: quote.quote.sim.taoAmount,
            novaFee: quote.novaFee
        )
    }

    func createStakeChange(removing unstakeModel: SubtensorUnstakeModel) -> SubtensorConfirmStakeChange? {
        guard model.target.isRoot, !isPositionsSyncFailed, let group = liveGroup() else {
            return nil
        }

        let plan = unstakeModel.plan
        let removed = plan.rebuilt(from: group)?.amount ?? plan.amount
        let after = plan.emptiesGroup(group) ? 0 : group.totalAlpha.subtractOrZero(removed)

        return SubtensorConfirmStakeChange(before: group.totalAlpha, after: after)
    }

    func refreshHolds() {
        guard
            model.target.isRoot,
            case let .unstake(unstakeModel) = model.mode,
            unstakeModel.plan.hotkeys != [model.validator.hotkey] else {
            return
        }

        interactor.loadRootHolds(for: unstakeModel.plan.hotkeys)
    }

    func didReceiveRootHolds(_ holds: [AccountId: SubtensorRootHold]) {
        self.holds = holds
    }

    func isExitGroupUnchanged() -> Bool {
        guard case let .unstake(unstakeModel) = model.mode, unstakeModel.plan.single == nil else {
            return true
        }

        return SubtensorConfirmTapRule.verifiedPlan(for: unstakeModel, in: positionsState) != nil
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

    func emptiesPosition(_ operation: SubtensorOperation, group: SubtensorPortfolioGroup?) -> Bool {
        switch operation {
        case let .rootUnstakeGroup(exits, partials), let .subnetSellGroup(exits, partials, _, _, _, _):
            let groupHotkeys = Set(group?.positions.map(\.hotkey) ?? [])
            return partials.isEmpty && groupHotkeys.isSubset(of: Set(exits))
        case .rootStake, .rootUnstake, .rootClaim, .subnetBuy, .subnetSell:
            return false
        }
    }

    func confirmUnstake(_ unstakeModel: SubtensorUnstakeModel) {
        let group = liveGroup()
        let plan = unstakeModel.plan
        let rebuilt = group.flatMap { plan.rebuilt(from: $0) }

        guard group == nil || rebuilt != nil else {
            presentGroupChanged()
            return
        }

        let liveAmount = rebuilt?.amount
        let positions = Dictionary((group?.positions ?? []).map { ($0.hotkey, $0.stakeAlpha) }) { first, _ in first }

        var dependencies = SubtensorUnstakeValidatingDependencies(
            netuid: unstakeModel.netuid,
            accountId: model.account.chainAccount.accountId,
            hotkey: model.validator.hotkey,
            amount: liveAmount,
            positionAlpha: liveAmount,
            positions: positions,
            plan: plan,
            groupHotkeys: unstakeModel.groupHotkeys,
            availability: group?.availability,
            balance: balance,
            fee: networkFee,
            existentialDeposit: existentialDeposit,
            preflight: preflight,
            holds: holds,
            currentBlock: currentBlock,
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
        dependencies.analytics = createValidationReporter()

        dataValidationFactory.validateUnstake(for: dependencies, locale: selectedLocale) { [weak self] in
            self?.handOffAtTap()
        }
    }
}
