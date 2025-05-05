import Foundation
import BigInt
import Foundation_iOS

extension ParachainStaking {
    final class ValidatorFactory: ParaStkValidatorFactoryProtocol {
        weak var view: ControllerBackedProtocol?

        var collatorStakingPresentable: CollatorStakingErrorPresentable { presentable }
        let assetDisplayInfo: AssetBalanceDisplayInfo
        let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
        let presentable: ParachainStakingErrorPresentable

        private(set) lazy var balanceViewModelFactory: BalanceViewModelFactoryProtocol = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        private(set) lazy var quantityFormatter = NumberFormatter.quantity.localizableResource()

        init(
            presentable: ParachainStakingErrorPresentable,
            assetDisplayInfo: AssetBalanceDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
        ) {
            self.presentable = presentable
            self.assetDisplayInfo = assetDisplayInfo
            self.priceAssetInfoFactory = priceAssetInfoFactory
        }
    }
}

extension ParachainStaking.ValidatorFactory {
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

    func notRevokingWhileStakingMore(
        collator: AccountId?,
        scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentCantStakeMoreWhileRevoking(view, locale: locale)

        }, preservesCondition: {
            guard let scheduledRequests = scheduledRequests else {
                return true
            }

            guard let collator = collator else {
                return false
            }

            return !scheduledRequests.contains { $0.collatorId == collator && $0.isRevoke }
        })
    }

    func canUnstake(
        amount: Decimal?,
        staked: BigUInt?,
        from collator: AccountId?,
        scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?,
        locale: Locale
    ) -> DataValidating {
        let precision = assetDisplayInfo.assetPrecision
        let optAmountInPlank = amount.flatMap {
            $0.toSubstrateAmount(precision: precision)
        }

        let amountInPlank = optAmountInPlank ?? 0

        return ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentUnstakingAmountTooHigh(view, locale: locale)

        }, preservesCondition: {
            guard let scheduledRequests = scheduledRequests else {
                return true
            }

            guard let collator = collator, let staked = staked else {
                return false
            }

            let notUnstakingCollator = !scheduledRequests.contains(where: { $0.collatorId == collator })
            return amountInPlank > 0 && amountInPlank <= staked && notUnstakingCollator
        })
    }

    func willRemainTopStaker(
        unstakingAmount: Decimal?,
        staked: BigUInt?,
        collator: ParachainStaking.CandidateMetadata?,
        minDelegationParams: ParaStkMinDelegationParams,
        locale: Locale
    ) -> DataValidating {
        let precision = assetDisplayInfo.assetPrecision
        let optUnstakingAmountInPlank = unstakingAmount.flatMap {
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

            self?.presentable.presentWontReceiveRewardsAfterUnstaking(
                view,
                minStake: minStakeString ?? "",
                action: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )
        }, preservesCondition: {
            guard
                let collator = collator,
                let unstakingAmountInPlank = optUnstakingAmountInPlank,
                let staked = staked,
                staked > unstakingAmountInPlank,
                let atLeastAtStake = minDelegationParams.atLeastAtStake else {
                return true
            }

            let amountAfterUnstaking = staked - unstakingAmountInPlank

            let lowestAmount = collator.lowestTopDelegationAmount
            let becomeOutTopStakers = staked >= lowestAmount &&
                amountAfterUnstaking < lowestAmount &&
                amountAfterUnstaking >= atLeastAtStake

            return !(collator.topCapacity.isFull && becomeOutTopStakers && !collator.bottomCapacity.isEmpty)
        })
    }

    func shouldUnstakeAll(
        unstakingAmount: Decimal?,
        staked: BigUInt?,
        minDelegationParams: ParaStkMinDelegationParams,
        locale: Locale
    ) -> DataValidating {
        let precision = assetDisplayInfo.assetPrecision
        let optUnstakingAmountInPlank = unstakingAmount.flatMap {
            $0.toSubstrateAmount(precision: precision)
        }

        return WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let view = self?.view else {
                return
            }

            let minStakeString: String?

            if let atLeastAtStake = minDelegationParams.atLeastAtStake {
                let minStake = Decimal.fromSubstrateAmount(atLeastAtStake, precision: precision)

                minStakeString = self?.balanceViewModelFactory.amountFromValue(
                    minStake ?? 0
                ).value(for: locale)
            } else {
                minStakeString = ""
            }

            self?.presentable.presentUnstakeAll(
                view,
                minStake: minStakeString ?? "",
                action: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )
        }, preservesCondition: {
            guard
                let unstakingAmountInPlank = optUnstakingAmountInPlank,
                let staked = staked,
                let atLeastAtStake = minDelegationParams.atLeastAtStake else {
                return false
            }

            let amountAfterUnstaking = staked - unstakingAmountInPlank

            return amountAfterUnstaking == 0 || amountAfterUnstaking >= atLeastAtStake
        })
    }

    func canRedeem(
        amount: Decimal?,
        collators: Set<AccountId>?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentCantRedeem(view, locale: locale)

        }, preservesCondition: {
            guard let collators = collators, let amount = amount else {
                return false
            }

            return amount > 0 && !collators.isEmpty
        })
    }

    func canRebond(
        collator: AccountId,
        scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentCantRebond(view, locale: locale)

        }, preservesCondition: {
            if scheduledRequests?.first(where: { $0.collatorId == collator }) != nil {
                return true
            } else {
                return false
            }
        })
    }

    func isActiveCollator(
        for metadata: ParachainStaking.CandidateMetadata?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentCantStakeInactiveCollator(view, locale: locale)

        }, preservesCondition: {
            if let metadata = metadata, metadata.isActive {
                return true
            } else {
                return false
            }
        })
    }
}
