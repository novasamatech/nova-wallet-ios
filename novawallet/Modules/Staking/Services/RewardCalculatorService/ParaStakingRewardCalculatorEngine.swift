import Foundation
import BigInt

protocol ParaStakingRewardCalculatorEngineProtocol {
    var totalIssuance: BigUInt { get }
    var totalStaked: BigUInt { get }

    func calculateEarnings(
        amount: Decimal,
        collatorAccountId: AccountId,
        period: CalculationPeriod
    ) throws -> Decimal

    func calculateMaxEarnings(
        amount: Decimal,
        period: CalculationPeriod
    ) -> Decimal

    func calculateAvgEarnings(
        amount: Decimal,
        period: CalculationPeriod
    ) -> Decimal
}

enum ParaStakingRewardCalculatorEngineError: Error {
    case missingCollator(_ collatorAccountId: AccountId)
}

final class ParaStakingRewardCalculatorEngine {
    let totalIssuance: BigUInt
    let totalStaked: BigUInt
    let inflation: ParachainStaking.InflationConfig
    let parachainBond: ParachainStaking.ParachainBondConfig
    let selectedCollators: SelectedRoundCollators
    let assetPrecision: Int16

    init(
        totalIssuance: BigUInt,
        totalStaked: BigUInt,
        inflation: ParachainStaking.InflationConfig,
        parachainBond: ParachainStaking.ParachainBondConfig,
        selectedCollators: SelectedRoundCollators,
        assetPrecision: Int16
    ) {
        self.totalIssuance = totalIssuance
        self.totalStaked = totalStaked
        self.inflation = inflation
        self.parachainBond = parachainBond
        self.selectedCollators = selectedCollators
        self.assetPrecision = assetPrecision
    }

    private(set) lazy var collatorCommision: Decimal = {
        Decimal.fromSubstratePerbill(value: selectedCollators.commission) ?? 0.0
    }()

    private(set) lazy var parachainBondPercent: Decimal = {
        Decimal.fromSubstratePercent(value: parachainBond.percent) ?? 0.0
    }()

    private(set) lazy var averageStake: Decimal = {
        let collatorsCount = selectedCollators.collators.count
        guard collatorsCount > 0 else {
            return 0.0
        }

        let decimalStake = Decimal.fromSubstrateAmount(
            totalStaked,
            precision: assetPrecision
        ) ?? 0

        return decimalStake / Decimal(collatorsCount)
    }()

    private(set) lazy var minStake: Decimal = {
        guard
            let stake = selectedCollators.collators.min(
                by: { $0.snapshot.total < $1.snapshot.total }
            )?.snapshot.total else {
            return 0.0
        }

        let decimalStake = Decimal.fromSubstrateAmount(
            stake,
            precision: assetPrecision
        ) ?? 0

        return decimalStake
    }()

    private func annualInlation() throws -> Decimal {
        let result: BigUInt

        if totalStaked < inflation.expect.min.value {
            result = inflation.annual.min.value
        } else if totalStaked > inflation.expect.max.value {
            result = inflation.annual.max.value
        } else {
            result = inflation.annual.ideal.value
        }

        guard let decimalResult = Decimal.fromSubstratePerbill(value: result) else {
            throw CommonError.dataCorruption
        }

        return decimalResult
    }

    private func calculateAnnualReturn(for stakeDeviation: Decimal) throws -> Decimal {
        guard
            let decimalTotalIssuance = Decimal.fromSubstrateAmount(
                totalIssuance,
                precision: assetPrecision
            ),
            let decimalTotalStaked = Decimal.fromSubstrateAmount(
                totalStaked,
                precision: assetPrecision
            )
        else {
            throw CommonError.dataCorruption
        }

        guard decimalTotalIssuance > 0.0, decimalTotalStaked > 0.0 else {
            return 0.0
        }

        let stakedPortion = decimalTotalStaked / decimalTotalIssuance

        let decimalInflation = try annualInlation()

        let decimalReturn = (decimalInflation / stakedPortion) * stakeDeviation

        return decimalReturn * (1.0 - parachainBondPercent) * (1.0 - collatorCommision)
    }
}

extension ParaStakingRewardCalculatorEngine: ParaStakingRewardCalculatorEngineProtocol {
    func calculateEarnings(
        amount: Decimal,
        collatorAccountId: AccountId,
        period: CalculationPeriod
    ) throws -> Decimal {
        guard
            let stake = selectedCollators.collators.first(
                where: { $0.accountId == collatorAccountId }
            )?.snapshot.total,
            let decimalStake = Decimal.fromSubstrateAmount(stake, precision: assetPrecision),
            decimalStake > 0.0 else {
            throw ParaStakingRewardCalculatorEngineError.missingCollator(collatorAccountId)
        }

        let annualReturn = try calculateAnnualReturn(for: averageStake / decimalStake)

        let dailyReturn = annualReturn / CalculationPeriod.daysInYear

        return amount * dailyReturn * Decimal(period.inDays)
    }

    func calculateMaxEarnings(
        amount: Decimal,
        period: CalculationPeriod
    ) -> Decimal {
        guard minStake > 0.0 else {
            return 0.0
        }

        if let annualReturn = try? calculateAnnualReturn(for: averageStake / minStake) {
            let dailyReturn = annualReturn / CalculationPeriod.daysInYear

            return amount * dailyReturn * Decimal(period.inDays)
        } else {
            return 0.0
        }
    }

    func calculateAvgEarnings(
        amount: Decimal,
        period: CalculationPeriod
    ) -> Decimal {
        guard minStake > 0.0 else {
            return 0.0
        }

        if let annualReturn = try? calculateAnnualReturn(for: 1.0) {
            let dailyReturn = annualReturn / CalculationPeriod.daysInYear

            return amount * dailyReturn * Decimal(period.inDays)
        } else {
            return 0.0
        }
    }
}
