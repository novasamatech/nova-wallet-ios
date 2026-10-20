import Foundation

extension SubtensorConfirmPresenter {
    func createStakeOperation(
        amount: Balance,
        limitPrice: Balance?,
        quote: SubtensorTradeQuote?
    ) -> SubtensorOperation? {
        guard !model.target.isRoot else {
            return .rootStake(hotkey: model.validator.hotkey, amount: amount)
        }

        guard let limitPrice, let quote else {
            return nil
        }

        return .subnetBuy(
            hotkey: model.validator.hotkey,
            netuid: model.target.netuid,
            grossTao: amount,
            limitPrice: limitPrice,
            novaFee: quote.novaFee
        )
    }

    func createStakeChange() -> SubtensorConfirmStakeChange? {
        switch model.mode {
        case let .stake(amount):
            return createStakeChange(adding: amount)
        case let .unstake(unstakeModel):
            return createStakeChange(removing: unstakeModel)
        }
    }

    func createStakeChange(adding amount: Balance) -> SubtensorConfirmStakeChange? {
        guard model.origin == .addStake, !isPositionsSyncFailed, positionsState != nil else {
            return nil
        }

        let before = liveGroup()?.totalAlpha ?? 0

        return SubtensorConfirmStakeChange(before: before, after: before + amount)
    }

    func hotkeyCountAfterOperation(in group: SubtensorPortfolioGroup?) -> Int {
        let hotkeys = Set(group?.positions.map(\.hotkey) ?? [])

        guard case .stake = model.mode else {
            return hotkeys.count
        }

        return hotkeys.union([model.validator.hotkey]).count
    }

    func confirmStake(amount: Balance) {
        var dependencies = SubtensorStakeValidatingDependencies(
            amount: amount,
            balance: balance,
            fee: networkFee,
            preflight: preflight,
            netuid: model.target.netuid,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            onFeeRefresh: { [weak self] in
                self?.refreshFee()
            },
            onPreflightRefresh: { [weak self] in
                self?.refreshPreflight()
            }
        )

        dependencies.quoteContext = createQuoteContext()
        dependencies.analytics = createValidationReporter()

        dataValidationFactory.validateStake(for: dependencies, locale: selectedLocale) { [weak self] in
            self?.handOffAtTap()
        }
    }
}
