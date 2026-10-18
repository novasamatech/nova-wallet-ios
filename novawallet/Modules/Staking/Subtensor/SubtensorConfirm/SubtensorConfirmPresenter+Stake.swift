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

    func createStakeChange(adding amount: Balance) -> SubtensorConfirmStakeChange? {
        guard model.origin == .addStake, !isPositionsSyncFailed, positionsState != nil else {
            return nil
        }

        let before = liveGroup()?.totalAlpha ?? 0

        return SubtensorConfirmStakeChange(before: before, after: before + amount)
    }

    func confirmStake(amount: Balance) {
        var dependencies = SubtensorStakeValidatingDep(
            amount: amount,
            balance: balance,
            fee: fee,
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

        dataValidationFactory.validateStake(for: dependencies, locale: selectedLocale) { [weak self] in
            self?.handOffAtTap()
        }
    }
}
