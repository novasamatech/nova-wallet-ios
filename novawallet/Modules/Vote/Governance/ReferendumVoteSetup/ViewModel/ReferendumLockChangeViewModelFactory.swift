import Foundation
import SoraFoundation

protocol ReferendumLockChangeViewModelFactoryProtocol {
    func createAmountViewModel(
        from diff: GovernanceLockStateDiff,
        locale: Locale
    ) -> ReferendumLockTransitionViewModel?

    func createPeriodViewModel(
        from diff: GovernanceLockStateDiff,
        blockNumber: BlockNumber,
        blockTime: BlockTime,
        locale: Locale
    ) -> ReferendumLockTransitionViewModel?
}

final class ReferendumLockChangeViewModelFactory {
    let balanceFormatter: LocalizableResource<TokenFormatter>
    let amountFormatter: LocalizableResource<LocalizableDecimalFormatting>
    let assetDisplayInfo: AssetBalanceDisplayInfo

    init(
        assetDisplayInfo: AssetBalanceDisplayInfo,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()
    ) {
        balanceFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: assetDisplayInfo)
        amountFormatter = assetBalanceFormatterFactory.createDisplayFormatter(for: assetDisplayInfo)
        self.assetDisplayInfo = assetDisplayInfo
    }
}

extension ReferendumLockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol {
    func createAmountViewModel(
        from diff: GovernanceLockStateDiff,
        locale: Locale
    ) -> ReferendumLockTransitionViewModel? {
        guard
            let fromAmountDecimal = Decimal.fromSubstrateAmount(
                diff.before.maxLockedAmount,
                precision: assetDisplayInfo.assetPrecision
            ),
            let fromAmountString = amountFormatter.value(for: locale).stringFromDecimal(fromAmountDecimal) else {
            return nil
        }

        let toAmountString: String
        let change: ReferendumLockTransitionViewModel.Change?

        let balanceFormatter = balanceFormatter.value(for: locale)

        if let toState = diff.after {
            guard
                let toAmountDecimal = Decimal.fromSubstrateAmount(
                    toState.maxLockedAmount,
                    precision: assetDisplayInfo.assetPrecision
                ) else {
                return nil
            }

            toAmountString = balanceFormatter.stringFromDecimal(toAmountDecimal) ?? ""

            if toAmountDecimal > fromAmountDecimal {
                let changeAmountString = balanceFormatter.stringFromDecimal(toAmountDecimal - fromAmountDecimal) ?? ""
                change = .init(isIncrease: true, value: changeAmountString)
            } else if toAmountDecimal < fromAmountDecimal {
                let changeAmountString = balanceFormatter.stringFromDecimal(fromAmountDecimal - toAmountDecimal) ?? ""
                change = .init(isIncrease: false, value: changeAmountString)
            } else {
                change = nil
            }

        } else {
            toAmountString = balanceFormatter.stringFromDecimal(fromAmountDecimal) ?? ""
            change = nil
        }

        return .init(fromValue: fromAmountString, toValue: toAmountString, change: change)
    }

    func createPeriodViewModel(
        from diff: GovernanceLockStateDiff,
        blockNumber: BlockNumber,
        blockTime: BlockTime,
        locale: Locale
    ) -> ReferendumLockTransitionViewModel? {
        let fromBlock = max(diff.before.lockedUntil ?? blockNumber, blockNumber)

        let fromPeriod = blockNumber.secondsTo(block: fromBlock, blockDuration: blockTime)
        let fromPeriodString = fromPeriod.localizedDaysHours(for: locale)

        let toPeriodString: String
        let change: ReferendumLockTransitionViewModel.Change?

        if let toState = diff.after {
            let toBlock = max(toState.lockedUntil ?? blockNumber, blockNumber)
            let toPeriod = blockNumber.secondsTo(block: toBlock, blockDuration: blockTime)

            toPeriodString = toPeriod.localizedDaysHours(for: locale)

            if fromPeriod < toPeriod, (toPeriod - fromPeriod).hoursFromSeconds > 0 {
                change = .init(
                    isIncrease: true,
                    value: R.string.localizable.commonMaximum(
                        (toPeriod - fromPeriod).localizedDaysHours(for: locale),
                        preferredLanguages: locale.rLanguages
                    )
                )
            } else if fromPeriod > toPeriod, (fromPeriod - toPeriod).hoursFromSeconds > 0 {
                change = .init(
                    isIncrease: false,
                    value: R.string.localizable.commonMaximum(
                        (fromPeriod - toPeriod).localizedDaysHours(for: locale),
                        preferredLanguages: locale.rLanguages
                    )
                )
            } else {
                change = nil
            }
        } else {
            toPeriodString = fromPeriodString
            change = nil
        }

        return .init(fromValue: fromPeriodString, toValue: toPeriodString, change: change)
    }
}
