import Foundation
import BigInt
import SoraFoundation

protocol ParaStkValidatorFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func delegatorNotExist(
        delegator: ParachainStaking.Delegator?,
        locale: Locale
    ) -> DataValidating

    func canStakeTopDelegations(
        amount: Decimal?,
        collator: ParachainStaking.CandidateMetadata?,
        existingBond: BigUInt?,
        locale: Locale
    ) -> DataValidating

    func canStakeBottomDelegations(
        amount: Decimal?,
        collator: ParachainStaking.CandidateMetadata?,
        existingBond: BigUInt?,
        locale: Locale
    ) -> DataValidating

    func hasMinStake(
        amount: Decimal?,
        minTechStake: BigUInt?,
        locale: Locale
    ) -> DataValidating

    func notExceedsMaxCollators(
        delegator: ParachainStaking.Delegator?,
        maxCollatorsAllowed: UInt32?,
        locale: Locale
    ) -> DataValidating
}

extension ParachainStaking {
    final class ValidatorFactory: ParaStkValidatorFactoryProtocol {
        weak var view: (Localizable & ControllerBackedProtocol)?

        var basePresentable: BaseErrorPresentable { presentable }
        let assetDisplayInfo: AssetBalanceDisplayInfo

        let presentable: ParachainStakingErrorPresentable

        private lazy var balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo
        )

        private lazy var quantityFormatter = NumberFormatter.quantity.localizableResource()

        init(
            presentable: ParachainStakingErrorPresentable,
            assetDisplayInfo: AssetBalanceDisplayInfo
        ) {
            self.presentable = presentable
            self.assetDisplayInfo = assetDisplayInfo
        }
    }
}

extension ParachainStaking.ValidatorFactory {
    func delegatorNotExist(delegator: ParachainStaking.Delegator?, locale: Locale) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentDelegatorExists(view, locale: locale)
        }, preservesCondition: {
            delegator == nil
        })
    }

    func canStakeTopDelegations(
        amount: Decimal?,
        collator: ParachainStaking.CandidateMetadata?,
        existingBond: BigUInt?,
        locale: Locale
    ) -> DataValidating {
        let precision = assetDisplayInfo.assetPrecision
        let optAmountInPlank = amount.flatMap {
            $0.toSubstrateAmount(precision: precision)
        }

        return WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let view = self?.view else {
                return
            }

            let minStake = Decimal.fromSubstrateAmount(
                collator?.lowestTopDelegationAmount ?? 0,
                precision: precision
            )

            let minStakeString = self?.balanceViewModelFactory.amountFromValue(
                minStake ?? 0
            ).value(for: locale)

            self?.presentable.presentWontReceiveRewards(
                view,
                minStake: minStakeString ?? "",
                action: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )
        }, preservesCondition: {
            guard let collator = collator, let newDelegationAmount = optAmountInPlank else {
                return false
            }

            let totalAmountAfterStake = newDelegationAmount + (existingBond ?? 0)

            return !collator.topCapacity.isFull ||
                totalAmountAfterStake > collator.lowestTopDelegationAmount
        })
    }

    func canStakeBottomDelegations(
        amount: Decimal?,
        collator: ParachainStaking.CandidateMetadata?,
        existingBond: BigUInt?,
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

            let minStake = Decimal.fromSubstrateAmount(
                collator?.lowestBottomDelegationAmount ?? 0,
                precision: precision
            )

            let minStakeString = self?.balanceViewModelFactory.amountFromValue(
                minStake ?? 0
            ).value(for: locale)

            self?.presentable.presentCantStakeCollator(
                view,
                minStake: minStakeString ?? "",
                locale: locale
            )
        }, preservesCondition: {
            guard let collator = collator, let newDelegationAmount = optAmountInPlank else {
                return false
            }

            let totalAmountAfterStake = newDelegationAmount + (existingBond ?? 0)

            return !collator.bottomCapacity.isFull ||
                totalAmountAfterStake > collator.lowestBottomDelegationAmount
        })
    }

    func hasMinStake(amount: Decimal?, minTechStake: BigUInt?, locale: Locale) -> DataValidating {
        let precision = assetDisplayInfo.assetPrecision
        let optAmountInPlank = amount.flatMap {
            $0.toSubstrateAmount(precision: precision)
        }

        return ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            let minStake = Decimal.fromSubstrateAmount(
                minTechStake ?? 0,
                precision: precision
            )

            let minStakeString = self?.balanceViewModelFactory.amountFromValue(
                minStake ?? 0
            ).value(for: locale)

            self?.presentable.presentStakeAmountTooLow(
                view,
                minStake: minStakeString ?? "",
                locale: locale
            )
        }, preservesCondition: {
            guard let minTechStake = minTechStake, let amountInPlank = optAmountInPlank else {
                return false
            }

            return amountInPlank >= minTechStake
        })
    }

    func notExceedsMaxCollators(
        delegator: ParachainStaking.Delegator?,
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

            self?.presentable.presentDelegatorFull(
                view,
                maxAllowed: maxAllowed ?? "",
                locale: locale
            )

        }, preservesCondition: {
            guard let delegator = delegator else {
                // there were no delegations previously
                return true
            }

            guard let maxCollatorsAllowed = maxCollatorsAllowed else {
                return false
            }

            return delegator.delegations.count < Int(maxCollatorsAllowed)
        })
    }
}
