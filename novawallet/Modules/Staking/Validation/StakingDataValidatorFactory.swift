import Foundation
import SoraFoundation
import IrohaCrypto
import BigInt

struct MinStakeIsNotViolatedParams {
    let networkInfo: NetworkStakingInfo?
    let minNominatorBond: BigUInt?
    let votersCount: UInt32?
}

protocol StakingDataValidatingFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func canUnbond(amount: Decimal?, bonded: Decimal?, locale: Locale) -> DataValidating
    func canRebond(amount: Decimal?, unbonding: Decimal?, locale: Locale) -> DataValidating

    func has(
        controller: ChainAccountResponse?,
        for address: AccountAddress,
        locale: Locale
    ) -> DataValidating

    func has(
        stash: ChainAccountResponse?,
        for address: AccountAddress,
        locale: Locale
    ) -> DataValidating

    func unbondingsLimitNotReached(_ count: Int?, locale: Locale) -> DataValidating
    func controllerBalanceIsNotZero(_ balance: Decimal?, locale: Locale) -> DataValidating

    func canNominate(
        amount: Decimal?,
        minimalBalance: Decimal?,
        minNominatorBond: Decimal?,
        locale: Locale
    ) -> DataValidating

    func rewardIsHigherThanFee(
        reward: Decimal?,
        fee: Decimal?,
        locale: Locale
    ) -> DataValidating

    func minStakeNotCrossed(
        for inputAmount: Decimal,
        params: MinStakeCrossedParams,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> DataValidating

    func ledgerNotExist(
        stakingLedger: StakingLedger?,
        locale: Locale
    ) -> DataValidating

    func hasRedeemable(stakingLedger: StakingLedger?, in era: UInt32?, locale: Locale) -> DataValidating

    func maxNominatorsCountNotApplied(
        counterForNominators: UInt32?,
        maxNominatorsCount: UInt32?,
        hasExistingNomination: Bool,
        locale: Locale
    ) -> DataValidating

    func minRewardableStakeIsNotViolated(
        amount: Decimal?,
        params: MinStakeIsNotViolatedParams,
        assetInfo: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating

    func minRewardableStakeIsNotViolated(
        amount: Decimal?,
        rewardableStake: BigUInt?,
        assetInfo: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating

    func allowsNewNominators(flag: Bool, locale: Locale) -> DataValidating
}

final class StakingDataValidatingFactory {
    weak var view: (ControllerBackedProtocol & Localizable)?

    var basePresentable: BaseErrorPresentable { presentable }

    let presentable: StakingErrorPresentable

    let balanceFactory: BalanceViewModelFactoryProtocol?

    init(presentable: StakingErrorPresentable, balanceFactory: BalanceViewModelFactoryProtocol? = nil) {
        self.presentable = presentable
        self.balanceFactory = balanceFactory
    }
}

extension StakingDataValidatingFactory: StakingDataValidatingFactoryProtocol {
    func canUnbond(amount: Decimal?, bonded: Decimal?, locale: Locale) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentUnbondingTooHigh(from: view, locale: locale)

        }, preservesCondition: {
            if let amount = amount,
               let bonded = bonded {
                return amount <= bonded
            } else {
                return false
            }
        })
    }

    func canRebond(amount: Decimal?, unbonding: Decimal?, locale: Locale) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentRebondingTooHigh(from: view, locale: locale)

        }, preservesCondition: {
            if let amount = amount,
               let unbonding = unbonding {
                return amount <= unbonding
            } else {
                return false
            }
        })
    }

    func has(
        controller: ChainAccountResponse?,
        for address: AccountAddress,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentMissingController(from: view, address: address, locale: locale)
        }, preservesCondition: { controller?.toAddress() == address })
    }

    func has(
        stash: ChainAccountResponse?,
        for address: AccountAddress,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentMissingStash(from: view, address: address, locale: locale)
        }, preservesCondition: { stash?.toAddress() == address })
    }

    func unbondingsLimitNotReached(_ count: Int?, locale: Locale) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentUnbondingLimitReached(from: view, locale: locale)
        }, preservesCondition: {
            if let count = count, count < SubstrateConstants.maxUnbondingRequests {
                return true
            } else {
                return false
            }
        })
    }

    func rewardIsHigherThanFee(
        reward: Decimal?,
        fee: Decimal?,
        locale: Locale
    ) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentRewardIsLessThanFee(from: view, action: {
                delegate.didCompleteWarningHandling()
            }, locale: locale)
        }, preservesCondition: {
            if let reward = reward, let fee = fee {
                return reward > fee
            } else {
                return false
            }
        })
    }

    func controllerBalanceIsNotZero(_ balance: Decimal?, locale: Locale) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentControllerBalanceIsZero(
                from: view,
                action: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )
        }, preservesCondition: {
            if let balance = balance, balance > 0 {
                return true
            } else {
                return false
            }
        })
    }

    func minStakeNotCrossed(
        for inputAmount: Decimal,
        params: MinStakeCrossedParams,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> DataValidating {
        let inputAmountInPlank = inputAmount.toSubstrateAmount(
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) ?? 0

        let stakedAmountInPlank = params.stakedAmountInPlank
        let minStake = params.minStake

        return WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let balanceFactory = self?.balanceFactory else {
                return
            }

            let stakedAmount = stakedAmountInPlank ?? 0
            let diff = stakedAmount >= inputAmountInPlank ? stakedAmount - inputAmountInPlank : 0

            let minStakeDecimal = (minStake ?? 0).decimal(precision: chainAsset.asset.precision)
            let diffDecimal = diff.decimal(precision: chainAsset.asset.precision)

            let minStakeString = balanceFactory.amountFromValue(minStakeDecimal).value(for: locale)
            let diffString = balanceFactory.amountFromValue(diffDecimal).value(for: locale)

            self?.presentable.presentCrossedMinStake(
                from: self?.view,
                minStake: minStakeString,
                remaining: diffString,
                action: {
                    params.unstakeAllHandler()
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )

        }, preservesCondition: {
            guard
                let stakedAmountInPlank = stakedAmountInPlank,
                let minStake = minStake,
                stakedAmountInPlank >= inputAmountInPlank else {
                return false
            }

            let diff = stakedAmountInPlank - inputAmountInPlank

            return diff == 0 || diff >= minStake
        })
    }

    func hasRedeemable(stakingLedger: StakingLedger?, in era: UInt32?, locale: Locale) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentNoRedeemables(from: view, locale: locale)
        }, preservesCondition: {
            if let era = era, let redeemable = stakingLedger?.redeemable(inEra: era), redeemable > 0 {
                return true
            } else {
                return false
            }
        })
    }

    func ledgerNotExist(
        stakingLedger: StakingLedger?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentControllerIsAlreadyUsed(from: view, locale: locale)
        }, preservesCondition: {
            stakingLedger == nil
        })
    }

    func canNominate(
        amount: Decimal?,
        minimalBalance: Decimal?,
        minNominatorBond: Decimal?,
        locale: Locale
    ) -> DataValidating {
        let minAmount: Decimal? = {
            if let minimalBalance = minimalBalance, let minNominatorBond = minNominatorBond {
                return max(minimalBalance, minNominatorBond)
            }

            if let minNominatorBond = minNominatorBond {
                return minNominatorBond
            }

            return minimalBalance
        }()

        return ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            let amountString = minAmount.map {
                self?.balanceFactory?.amountFromValue($0).value(for: locale) ?? ""
            } ?? ""

            self?.presentable.presentAmountTooLow(value: amountString, from: view, locale: locale)
        }, preservesCondition: {
            guard let amount = amount else {
                return false
            }

            return minAmount.map { amount >= $0 } ?? true
        })
    }

    func maxNominatorsCountNotApplied(
        counterForNominators: UInt32?,
        maxNominatorsCount: UInt32?,
        hasExistingNomination: Bool,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentMaxNumberOfNominatorsReached(from: view, locale: locale)
        }, preservesCondition: {
            if
                !hasExistingNomination,
                let counterForNominators = counterForNominators,
                let maxNominatorsCount = maxNominatorsCount {
                return counterForNominators < maxNominatorsCount
            } else {
                return true
            }
        })
    }

    func minRewardableStakeIsNotViolated(
        amount: Decimal?,
        params: MinStakeIsNotViolatedParams,
        assetInfo: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating {
        let optMinStake = params.networkInfo?.calculateMinimumStake(
            given: params.minNominatorBond, votersCount: params.votersCount
        )

        let optMinStakeDecimal = optMinStake.flatMap {
            Decimal.fromSubstrateAmount($0, precision: assetInfo.assetPrecision)
        }

        return WarningConditionViolation(onWarning: { [weak self] delegate in
            guard
                let view = self?.view,
                let minStakeDecimal = optMinStakeDecimal else {
                return
            }

            let amountString = self?.balanceFactory?.amountFromValue(
                minStakeDecimal,
                roundingMode: .up
            ).value(for: locale)

            self?.presentable.presentMinRewardableStakeViolated(
                from: view,
                action: {
                    delegate.didCompleteWarningHandling()
                },
                minStake: amountString ?? "",
                locale: locale
            )
        }, preservesCondition: {
            if
                let amount = amount,
                let votersCount = params.votersCount,
                params.networkInfo?.votersInfo?.hasVotersLimit(for: votersCount) == true,
                let minStakeDecimal = optMinStakeDecimal {
                return amount >= minStakeDecimal
            } else {
                return true
            }
        })
    }

    func minRewardableStakeIsNotViolated(
        amount: Decimal?,
        rewardableStake: BigUInt?,
        assetInfo: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating {
        let optMinStakeDecimal = rewardableStake.flatMap {
            Decimal.fromSubstrateAmount($0, precision: assetInfo.assetPrecision)
        }

        return WarningConditionViolation(onWarning: { [weak self] delegate in
            guard
                let view = self?.view,
                let minStakeDecimal = optMinStakeDecimal else {
                return
            }

            let amountString = self?.balanceFactory?.amountFromValue(
                minStakeDecimal,
                roundingMode: .up
            ).value(for: locale)

            self?.presentable.presentMinRewardableStakeViolated(
                from: view,
                action: {
                    delegate.didCompleteWarningHandling()
                },
                minStake: amountString ?? "",
                locale: locale
            )
        }, preservesCondition: {
            if
                let amount = amount,
                let minStakeDecimal = optMinStakeDecimal {
                return amount >= minStakeDecimal
            } else {
                return true
            }
        })
    }

    func allowsNewNominators(flag: Bool, locale: Locale) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentMaxNumberOfNominatorsReached(from: view, locale: locale)
        }, preservesCondition: {
            flag
        })
    }
}
