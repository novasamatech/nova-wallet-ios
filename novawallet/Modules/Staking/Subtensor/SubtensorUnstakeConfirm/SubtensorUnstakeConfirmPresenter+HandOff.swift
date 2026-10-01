import Foundation

extension SubtensorUnstakeConfirmPresenter {
    func applyTapGate() -> Bool {
        guard var state = quoteState else {
            return true
        }

        if state.isPriceMoved {
            guard state.acknowledgeLatest() else {
                presentQuoteMissing()
                return false
            }

            quoteState = state

            refreshFee()
            provideViewModel()

            return true
        }

        guard !state.raisePriceMovedIfCrossed() else {
            quoteState = state
            provideViewModel()
            return false
        }

        return true
    }

    func createVerifiedOperation() -> (operation: SubtensorStakingOperation, quote: SubtensorTradeQuote?)? {
        let exitHotkeys: [AccountId]?

        if unstakeModel.isFullUnstake {
            let verified = SubtensorConfirmTapRule.verifiedExitHotkeys(for: unstakeModel, in: positionsState)

            guard let verified else {
                presentGroupChanged()
                return nil
            }

            exitHotkeys = verified
        } else {
            exitHotkeys = nil
        }

        guard let state = quoteState else {
            return createOperation(exitHotkeys: exitHotkeys, limitPrice: nil, quotedTaoOut: nil).map { ($0, nil) }
        }

        switch SubtensorConfirmTapRule.quoteVerdict(latest: state.latest, acknowledged: state.acknowledged) {
        case let .proceed(latest, acknowledged) where !state.isPriceMoved:
            return createOperation(
                exitHotkeys: exitHotkeys,
                limitPrice: acknowledged.limitPrice,
                quotedTaoOut: latest.quote.sim.taoAmount
            ).map { ($0, latest) }
        case .quoteMissing:
            presentQuoteMissing()
            return nil
        case .proceed, .priceMoved:
            quoteState?.raisePriceMoved()
            provideViewModel()
            return nil
        }
    }

    func emptiesPosition(_ operation: SubtensorStakingOperation, group: SubtensorPortfolioGroup?) -> Bool {
        switch operation {
        case let .rootUnstakeAll(hotkeys), let .subnetSellAll(hotkeys, _, _, _):
            let groupHotkeys = Set(group?.positions.map(\.hotkey) ?? [])
            return groupHotkeys.isSubset(of: Set(hotkeys))
        case .rootStake, .rootUnstake, .subnetBuy, .subnetSell:
            return false
        }
    }

    func handOffAtTap() {
        guard !isHandingOff, let fee, let verified = createVerifiedOperation() else {
            return
        }

        let group = liveGroup()

        let request = SubtensorOperationResultRequest(
            operation: verified.operation,
            origin: model.origin,
            account: model.account,
            target: model.target,
            payAmount: unstakeModel.amount,
            quote: verified.quote,
            slippage: model.tolerance,
            validator: model.validator,
            estimatedNetworkFee: fee,
            stakeBefore: group?.totalAlpha ?? 0,
            groupHotkeyCount: group?.positions.count ?? 0,
            emptiesPosition: emptiesPosition(verified.operation, group: group),
            prices: SubtensorOperationResultPrices(taoPrice: price, alphaSpot: verified.quote?.quote.spotPrice),
            costBasis: model.target.isRoot ? nil : costBasis
        )

        isHandingOff = true
        view?.didStartLoading()

        wireframe.showOperationResult(from: view, request: request, delegate: self)
    }

    func getValidationDependencies() -> SubtensorUnstakeValidatingDep {
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

        if let quoteState {
            dependencies.quoteContext = SubtensorQuoteValidatingContext(
                latestQuote: quoteState.latest,
                acknowledgedLimit: quoteState.acknowledged?.limitPrice,
                tradesUnavailable: tradesUnavailable,
                onQuoteRefresh: { [weak self] in
                    self?.refreshQuote()
                }
            )
        }

        return dependencies
    }

    func finishHandOff() {
        isHandingOff = false
        view?.didStopLoading()
    }
}
