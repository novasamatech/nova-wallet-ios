import Foundation
import BigInt
import Foundation_iOS

protocol ParaStkYieldBoostValidatorFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func hasExecutionFee(
        _ fee: BigUInt?,
        locale: Locale?,
        errorClosure: @escaping () -> Void
    ) -> DataValidating

    func hasExecutionTime(
        _ time: AutomationTime.UnixTime?,
        locale: Locale?,
        errorClosure: @escaping () -> Void
    ) -> DataValidating

    func enoughBalanceForThreshold(
        _ threshold: Decimal?,
        balance: BigUInt?,
        extrinsicFee: ExtrinsicFeeProtocol?,
        assetInfo: AssetBalanceDisplayInfo,
        locale: Locale?
    ) -> DataValidating

    func enoughBalanceForExecutionFee(
        _ executionFee: BigUInt?,
        balance: BigUInt?,
        extrinsicFee: ExtrinsicFeeProtocol?,
        assetInfo: AssetBalanceDisplayInfo,
        locale: Locale?
    ) -> DataValidating

    func cancelForOtherCollatorsExcept(
        selectedCollatorId: AccountId?,
        tasks: [ParaStkYieldBoostState.Task]?,
        selectedCollatorName: String?,
        locale: Locale?
    ) -> DataValidating

    func cancellingTaskExists(
        for collatorId: AccountId?,
        tasks: [ParaStkYieldBoostState.Task]?,
        locale: Locale?
    ) -> DataValidating
}

final class ParaStkYieldBoostValidatorFactory {
    weak var view: ControllerBackedProtocol?

    var basePresentable: BaseErrorPresentable { presentable }
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let presentable: ParaStkYieldBoostErrorPresentable

    init(
        presentable: ParaStkYieldBoostErrorPresentable,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    ) {
        self.presentable = presentable
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }
}

extension ParaStkYieldBoostValidatorFactory: ParaStkYieldBoostValidatorFactoryProtocol {
    func hasExecutionTime(
        _ time: AutomationTime.UnixTime?,
        locale: Locale?,
        errorClosure: @escaping () -> Void
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentInvalidTaskExecutionTime(from: view, locale: locale)

            errorClosure()
        }, preservesCondition: {
            time != nil
        })
    }

    func enoughBalanceForThreshold(
        _ threshold: Decimal?,
        balance: BigUInt?,
        extrinsicFee: ExtrinsicFeeProtocol?,
        assetInfo: AssetBalanceDisplayInfo,
        locale: Locale?
    ) -> DataValidating {
        let optThresholdInPlank = threshold?.toSubstrateAmount(precision: assetInfo.assetPrecision)

        return ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view, let formatterFactory = self?.assetBalanceFormatterFactory else {
                return
            }

            let formatter = formatterFactory.createTokenFormatter(for: assetInfo)
                .value(for: locale ?? Locale.current)

            guard
                let balanceDecimal = Decimal.fromSubstrateAmount(balance ?? 0, precision: assetInfo.assetPrecision),
                let feeDecimal = Decimal.fromSubstrateAmount(
                    extrinsicFee?.amountForCurrentAccount ?? 0,
                    precision: assetInfo.assetPrecision
                ) else {
                return
            }

            let thresholdString = formatter.stringFromDecimal(threshold ?? 0) ?? ""
            let balanceString = formatter.stringFromDecimal(balanceDecimal) ?? ""
            let feeString = formatter.stringFromDecimal(feeDecimal) ?? ""

            self?.presentable.presentNotEnoughBalanceForThreshold(
                from: view,
                threshold: thresholdString,
                fee: feeString,
                balance: balanceString,
                locale: locale
            )

        }, preservesCondition: {
            guard
                let thresholdInPlank = optThresholdInPlank,
                let balance = balance else {
                return false
            }

            let fee = extrinsicFee?.amountForCurrentAccount ?? 0
            return balance >= thresholdInPlank + fee
        })
    }

    func enoughBalanceForExecutionFee(
        _ executionFee: BigUInt?,
        balance: BigUInt?,
        extrinsicFee: ExtrinsicFeeProtocol?,
        assetInfo: AssetBalanceDisplayInfo,
        locale: Locale?
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view, let formatterFactory = self?.assetBalanceFormatterFactory else {
                return
            }

            let formatter = formatterFactory.createTokenFormatter(for: assetInfo)
                .value(for: locale ?? Locale.current)

            let precision = assetInfo.assetPrecision

            guard
                let executionFeeDecimal = Decimal.fromSubstrateAmount(executionFee ?? 0, precision: precision),
                let balanceDecimal = Decimal.fromSubstrateAmount(balance ?? 0, precision: precision),
                let extrinsicFeeDecimal = Decimal.fromSubstrateAmount(
                    extrinsicFee?.amountForCurrentAccount ?? 0,
                    precision: precision
                ) else {
                return
            }

            let executionFeeString = formatter.stringFromDecimal(executionFeeDecimal) ?? ""
            let balanceString = formatter.stringFromDecimal(balanceDecimal) ?? ""
            let extrinsicFeeString = formatter.stringFromDecimal(extrinsicFeeDecimal) ?? ""

            self?.presentable.presentNotEnoughBalanceForExecutionFee(
                from: view,
                executionFee: executionFeeString,
                extrinsicFee: extrinsicFeeString,
                balance: balanceString,
                locale: locale
            )
        }, preservesCondition: {
            guard
                let executionFee = executionFee,
                let balance = balance else {
                return false
            }

            let extrinsicFee = extrinsicFee?.amountForCurrentAccount ?? 0

            return balance >= executionFee + extrinsicFee
        })
    }

    func cancelForOtherCollatorsExcept(
        selectedCollatorId: AccountId?,
        tasks: [ParaStkYieldBoostState.Task]?,
        selectedCollatorName: String?,
        locale: Locale?
    ) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentCancelTasksForCollators(
                from: view,
                collator: selectedCollatorName ?? "",
                action: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )
        }, preservesCondition: {
            guard let tasks = tasks else {
                return true
            }

            return !tasks.contains { $0.collatorId != selectedCollatorId }
        })
    }

    func cancellingTaskExists(
        for collatorId: AccountId?,
        tasks: [ParaStkYieldBoostState.Task]?,
        locale: Locale?
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentCancellingTaskNotExists(from: view, locale: locale)
        }, preservesCondition: {
            (tasks ?? []).contains { $0.collatorId == collatorId }
        })
    }

    func hasExecutionFee(
        _ fee: BigUInt?,
        locale: Locale?,
        errorClosure: @escaping () -> Void
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            defer {
                errorClosure()
            }

            guard let view = self?.view else {
                return
            }

            self?.basePresentable.presentFeeNotReceived(from: view, locale: locale)
        }, preservesCondition: { fee != nil })
    }
}
