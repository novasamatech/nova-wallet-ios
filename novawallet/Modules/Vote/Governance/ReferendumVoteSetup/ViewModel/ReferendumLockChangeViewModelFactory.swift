import Foundation
import SoraFoundation
import BigInt

protocol ReferendumLockChangeViewModelFactoryProtocol {
    func createTransferableAmountViewModel(
        resultLocked: BigUInt?,
        balance: AssetBalance,
        locks: AssetLocks,
        locale: Locale
    ) -> ReferendumLockTransitionViewModel?

    func createAmountViewModel(
        initLocked: BigUInt,
        resultLocked: BigUInt?,
        locale: Locale
    ) -> ReferendumLockTransitionViewModel?

    func createPeriodViewModel(
        initLockedUntil: BlockNumber,
        resultLockedUntil: BlockNumber?,
        blockNumber: BlockNumber,
        blockTime: BlockTime,
        locale: Locale
    ) -> ReferendumLockTransitionViewModel?

    func createDelegatedPeriodViewModel(
        fromDelegatedPeriod: Moment?,
        toDelegatedPeriod: Moment?,
        blockTime: BlockTime,
        locale: Locale
    ) -> ReferendumLockTransitionViewModel

    func createRemainedOtherLocksViewModel(
        locks: AssetLocks,
        locale: Locale
    ) -> GovernanceRemainedLockViewModel?
}

extension ReferendumLockChangeViewModelFactoryProtocol {
    func createTransferableAmountViewModel(
        from diff: GovernanceLockStateDiff,
        balance: AssetBalance,
        locks: AssetLocks,
        locale: Locale
    ) -> ReferendumLockTransitionViewModel? {
        createTransferableAmountViewModel(
            resultLocked: diff.after?.maxLockedAmount,
            balance: balance,
            locks: locks,
            locale: locale
        )
    }

    func createAmountTransitionAfterVotingViewModel(
        from diff: GovernanceLockStateDiff,
        locale: Locale
    ) -> ReferendumLockTransitionViewModel? {
        createAmountViewModel(
            initLocked: diff.before.maxLockedAmount,
            resultLocked: diff.after?.maxLockedAmount,
            locale: locale
        )
    }

    func createPeriodTransitionAfterVotingViewModel(
        from diff: GovernanceLockStateDiff,
        blockNumber: BlockNumber,
        blockTime: BlockTime,
        locale: Locale
    ) -> ReferendumLockTransitionViewModel? {
        let resultLockedUntil: BlockNumber?

        if let toState = diff.after {
            resultLockedUntil = toState.lockedUntil ?? blockNumber
        } else {
            resultLockedUntil = nil
        }

        return createPeriodViewModel(
            initLockedUntil: diff.before.lockedUntil ?? blockNumber,
            resultLockedUntil: resultLockedUntil,
            blockNumber: blockNumber,
            blockTime: blockTime,
            locale: locale
        )
    }

    func createAmountTransitionAfterDelegatingViewModel(
        from diff: GovernanceDelegateStateDiff,
        locale: Locale
    ) -> ReferendumLockTransitionViewModel? {
        createAmountViewModel(
            initLocked: diff.before.maxLockedAmount,
            resultLocked: diff.after?.maxLockedAmount,
            locale: locale
        )
    }

    func createPeriodTransitionAfterDelegatingViewModel(
        from diff: GovernanceDelegateStateDiff,
        blockTime: BlockTime,
        locale: Locale
    ) -> ReferendumLockTransitionViewModel? {
        createDelegatedPeriodViewModel(
            fromDelegatedPeriod: diff.before.undelegatingPeriod,
            toDelegatedPeriod: diff.after?.undelegatingPeriod,
            blockTime: blockTime,
            locale: locale
        )
    }
}

final class ReferendumLockChangeViewModelFactory {
    let balanceFormatter: LocalizableResource<TokenFormatter>
    let amountFormatter: LocalizableResource<LocalizableDecimalFormatting>
    let assetDisplayInfo: AssetBalanceDisplayInfo
    let votingLockId: String

    init(
        assetDisplayInfo: AssetBalanceDisplayInfo,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory(),
        votingLockId: String
    ) {
        balanceFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: assetDisplayInfo)
        amountFormatter = assetBalanceFormatterFactory.createDisplayFormatter(for: assetDisplayInfo)
        self.assetDisplayInfo = assetDisplayInfo
        self.votingLockId = votingLockId
    }
}

extension ReferendumLockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol {
    func createRemainedOtherLocksViewModel(
        locks: AssetLocks,
        locale: Locale
    ) -> GovernanceRemainedLockViewModel? {
        let otherLocks = locks.filter { $0.displayId != votingLockId }

        let newLocks = otherLocks.sorted { $0.amount > $1.amount }

        if let lockedAmount = newLocks.first?.amount, lockedAmount > 0 {
            let amountDecimal = Decimal.fromSubstrateAmount(
                lockedAmount,
                precision: assetDisplayInfo.assetPrecision
            ) ?? 0

            let balanceFormatter = balanceFormatter.value(for: locale)
            let amountString = balanceFormatter.stringFromDecimal(amountDecimal) ?? ""

            let types = newLocks.map { $0.lockType?.displayType.value(for: locale) ?? $0.displayId ?? "" }

            return .init(amount: amountString, modules: types)
        } else {
            return nil
        }
    }

    func createTransferableAmountViewModel(
        resultLocked: BigUInt?,
        balance: AssetBalance,
        locks: AssetLocks,
        locale: Locale
    ) -> ReferendumLockTransitionViewModel? {
        guard
            let fromAmountDecimal = Decimal.fromSubstrateAmount(
                balance.transferable,
                precision: assetDisplayInfo.assetPrecision
            ),
            let fromAmountString = amountFormatter.value(for: locale).stringFromDecimal(fromAmountDecimal) else {
            return nil
        }

        let toAmountString: String
        let change: ReferendumLockTransitionViewModel.Change?

        let balanceFormatter = balanceFormatter.value(for: locale)

        if let resultLocked = resultLocked {
            let otherLocks = locks
                .filter { $0.displayId != votingLockId }
                .map(\.amount)
                .max() ?? 0

            let newLocked = max(otherLocks, resultLocked)

            let newTransferable = balance.newTransferable(for: newLocked)

            guard
                let toAmountDecimal = Decimal.fromSubstrateAmount(
                    newTransferable,
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

    func createAmountViewModel(
        initLocked: BigUInt,
        resultLocked: BigUInt?,
        locale: Locale
    ) -> ReferendumLockTransitionViewModel? {
        guard
            let fromAmountDecimal = Decimal.fromSubstrateAmount(
                initLocked,
                precision: assetDisplayInfo.assetPrecision
            ),
            let fromAmountString = amountFormatter.value(for: locale).stringFromDecimal(fromAmountDecimal) else {
            return nil
        }

        let toAmountString: String
        let change: ReferendumLockTransitionViewModel.Change?

        let balanceFormatter = balanceFormatter.value(for: locale)

        if let resultLocked = resultLocked {
            guard
                let toAmountDecimal = Decimal.fromSubstrateAmount(
                    resultLocked,
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

    func createDelegatedPeriodViewModel(
        fromDelegatedPeriod: Moment?,
        toDelegatedPeriod: Moment?,
        blockTime: BlockTime,
        locale: Locale
    ) -> ReferendumLockTransitionViewModel {
        let change: ReferendumLockTransitionViewModel.Change?
        let fromPeriodString: String?
        let toPeriodString: String?

        if let fromDelegatedPeriod = fromDelegatedPeriod, let toDelegatedPeriod = toDelegatedPeriod {
            let fromTimeInterval = fromDelegatedPeriod.seconds(from: blockTime)
            fromPeriodString = fromTimeInterval.localizedFractionDays(
                for: locale,
                shouldAnnotate: false
            )

            let toTimeInterval = toDelegatedPeriod.seconds(from: blockTime)
            toPeriodString = toTimeInterval.localizedFractionDays(
                for: locale,
                shouldAnnotate: true
            )

            if
                fromTimeInterval < toTimeInterval,
                (toTimeInterval - fromTimeInterval).hoursFromSeconds > 0 {
                change = .init(
                    isIncrease: true,
                    value: R.string.localizable.commonMaximum(
                        (toTimeInterval - fromTimeInterval).localizedDaysHoursIncludingZero(for: locale),
                        preferredLanguages: locale.rLanguages
                    )
                )
            } else if
                fromTimeInterval > toTimeInterval,
                (fromTimeInterval - toTimeInterval).hoursFromSeconds > 0 {
                change = .init(
                    isIncrease: false,
                    value: R.string.localizable.commonMaximum(
                        (fromTimeInterval - toTimeInterval).localizedDaysHoursIncludingZero(for: locale),
                        preferredLanguages: locale.rLanguages
                    )
                )
            } else {
                change = nil
            }
        } else {
            let period = (toDelegatedPeriod ?? fromDelegatedPeriod)?.seconds(from: blockTime)
            toPeriodString = period?.localizedFractionDays(for: locale, shouldAnnotate: true)
            fromPeriodString = nil
            change = nil
        }

        return .init(
            fromValue: fromPeriodString ?? "",
            toValue: toPeriodString ?? "",
            change: change
        )
    }

    func createPeriodViewModel(
        initLockedUntil: BlockNumber,
        resultLockedUntil: BlockNumber?,
        blockNumber: BlockNumber,
        blockTime: BlockTime,
        locale: Locale
    ) -> ReferendumLockTransitionViewModel? {
        let fromBlock = max(initLockedUntil, blockNumber)

        let fromPeriod = blockNumber.secondsTo(block: fromBlock, blockDuration: blockTime)
        let fromPeriodString = fromPeriod.localizedFractionDays(for: locale, shouldAnnotate: false)

        let toPeriodString: String
        let change: ReferendumLockTransitionViewModel.Change?

        if let resultLockedUntil = resultLockedUntil {
            let toBlock = max(resultLockedUntil, blockNumber)
            let toPeriod = blockNumber.secondsTo(block: toBlock, blockDuration: blockTime)

            toPeriodString = toPeriod.localizedFractionDays(for: locale, shouldAnnotate: true)

            if fromPeriod < toPeriod, (toPeriod - fromPeriod).hoursFromSeconds > 0 {
                change = .init(
                    isIncrease: true,
                    value: R.string.localizable.commonMaximum(
                        (toPeriod - fromPeriod).localizedDaysHoursIncludingZero(for: locale),
                        preferredLanguages: locale.rLanguages
                    )
                )
            } else if fromPeriod > toPeriod, (fromPeriod - toPeriod).hoursFromSeconds > 0 {
                change = .init(
                    isIncrease: false,
                    value: R.string.localizable.commonMaximum(
                        (fromPeriod - toPeriod).localizedDaysHoursIncludingZero(for: locale),
                        preferredLanguages: locale.rLanguages
                    )
                )
            } else {
                change = nil
            }
        } else {
            toPeriodString = fromPeriod.localizedFractionDays(for: locale, shouldAnnotate: true)
            change = nil
        }

        return .init(fromValue: fromPeriodString, toValue: toPeriodString, change: change)
    }
}
