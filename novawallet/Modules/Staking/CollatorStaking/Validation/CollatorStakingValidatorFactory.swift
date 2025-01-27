import Foundation

extension CollatorStakingValidatorFactoryProtocol {
    var basePresentable: BaseErrorPresentable { collatorStakingPresentable }

    func delegatorNotExists(
        _ hasDelegator: Bool,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.collatorStakingPresentable.presentDelegatorExists(view, locale: locale)
        }, preservesCondition: {
            !hasDelegator
        })
    }

    func hasMinStake(
        amount: Decimal?,
        minStake: Balance?,
        locale: Locale
    ) -> DataValidating {
        let precision = assetDisplayInfo.assetPrecision
        let optAmountInPlank = amount.flatMap {
            $0.toSubstrateAmount(precision: precision)
        }

        return ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            let minStakeDecimal = Decimal.fromSubstrateAmount(
                minStake ?? 0,
                precision: precision
            )

            let minStakeString = self?.balanceViewModelFactory.amountFromValue(
                minStakeDecimal ?? 0
            ).value(for: locale)

            self?.collatorStakingPresentable.presentStakeAmountTooLow(
                view,
                minStake: minStakeString ?? "",
                locale: locale
            )
        }, preservesCondition: {
            guard let minStake = minStake, let amountInPlank = optAmountInPlank else {
                return false
            }

            return amountInPlank >= minStake
        })
    }

    func notExceedsMaxCollators(
        currentCollators: Set<AccountId>?,
        selectedCollator: AccountId?,
        maxCollatorsAllowed: UInt32?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            let maxAllowed = self?.quantityFormatter.value(for: locale).string(
                from: NSNumber(value: maxCollatorsAllowed ?? 0)
            )

            self?.collatorStakingPresentable.presentDelegatorFull(
                view,
                maxAllowed: maxAllowed ?? "",
                locale: locale
            )

        }, preservesCondition: {
            guard
                let currentCollators = currentCollators,
                !currentCollators.contains(selectedCollator) else {
                // there were no delegations previously
                return true
            }

            guard let maxCollatorsAllowed, let selectedCollator else {
                return false
            }

            return currentCollators.count < Int(maxCollatorsAllowed)
        })
    }
}
