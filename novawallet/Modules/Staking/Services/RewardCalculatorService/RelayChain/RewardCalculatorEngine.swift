import Foundation
import Operation_iOS
import BigInt
import NovaCrypto

enum CalculationPeriod {
    static let daysInYear: Decimal = 365.0

    case day
    case month
    case year
    case custom(days: Int)

    var inDays: Int {
        switch self {
        case .day:
            return 1
        case .month:
            return 30
        case .year:
            return 365
        case let .custom(value):
            return value
        }
    }
}

protocol RewardCalculatorEngineProtocol {
    func calculateEarnings(
        amount: Decimal,
        validatorAccountId: AccountId,
        isCompound: Bool,
        period: CalculationPeriod
    ) throws -> Decimal

    func calculateMaxEarnings(amount: Decimal, isCompound: Bool, period: CalculationPeriod) -> Decimal

    func calculateAvgEarnings(amount: Decimal, isCompound: Bool, period: CalculationPeriod) -> Decimal
}

extension RewardCalculatorEngineProtocol {
    func calculateValidatorReturn(
        validatorAccountId: AccountId,
        isCompound: Bool,
        period: CalculationPeriod
    ) throws -> Decimal {
        try calculateEarnings(
            amount: 1.0,
            validatorAccountId: validatorAccountId,
            isCompound: isCompound,
            period: period
        )
    }

    func calculateMaxReturn(isCompound: Bool, period: CalculationPeriod) -> Decimal {
        calculateMaxEarnings(amount: 1.0, isCompound: isCompound, period: period)
    }

    func calculateAvgReturn(isCompound: Bool, period: CalculationPeriod) -> Decimal {
        calculateAvgEarnings(amount: 1.0, isCompound: isCompound, period: period)
    }
}

enum RewardCalculatorEngineError: Error {
    case unexpectedValidator(accountId: Data)
}

class RewardCalculatorEngine: RewardCalculatorEngineProtocol {
    let totalIssuance: Decimal
    let validators: [EraValidatorInfo]
    let chainId: ChainModel.Id
    let assetPrecision: Int16
    let eraDurationInSeconds: TimeInterval

    private(set) lazy var totalStake: Decimal = {
        Decimal.fromSubstrateAmount(
            validators.map(\.exposure.total).reduce(0, +),
            precision: assetPrecision
        ) ?? 0.0
    }()

    var averageStake: Decimal {
        if !validators.isEmpty {
            return totalStake / Decimal(validators.count)
        } else {
            return 0.0
        }
    }

    var stakedPortion: Decimal {
        if totalIssuance > 0.0 {
            return totalStake / totalIssuance
        } else {
            return 0.0
        }
    }

    private(set) lazy var medianCommission: Decimal = {
        let profitable = validators
            .compactMap { Decimal.fromSubstratePerbill(value: $0.prefs.commission) }
            .sorted()
            .filter { $0 < 1.0 }

        guard !profitable.isEmpty else {
            return 0.0
        }

        let commission: Decimal

        let count = profitable.count

        if count % 2 == 0 {
            commission = (profitable[count / 2] + profitable[(count / 2) - 1]) / 2
        } else {
            commission = profitable[(count - 1) / 2]
        }

        return commission
    }()

    private(set) lazy var maxValidator: EraValidatorInfo? = {
        validators.max {
            calculateEarningsForValidator($0, amount: 1.0, isCompound: false, period: .year) <
                calculateEarningsForValidator($1, amount: 1.0, isCompound: false, period: .year)
        }
    }()

    init(
        chainId: ChainModel.Id,
        assetPrecision: Int16,
        totalIssuance: BigUInt,
        validators: [EraValidatorInfo],
        eraDurationInSeconds: TimeInterval
    ) {
        self.chainId = chainId
        self.assetPrecision = assetPrecision
        self.totalIssuance = Decimal.fromSubstrateAmount(
            totalIssuance,
            precision: assetPrecision
        ) ?? 0.0
        self.validators = validators
        self.eraDurationInSeconds = eraDurationInSeconds
    }

    func calculateAnnualInflation() -> Decimal {
        fatalError("Child class must override this method")
    }

    func calculateEraReturn(from _: Decimal) -> Decimal {
        fatalError("Child class must override this method")
    }

    func calculateReturnForStake(_ stake: Decimal, commission: Decimal) -> Decimal {
        let annualInflation = calculateAnnualInflation()
        return (annualInflation * averageStake / (stakedPortion * stake)) * (1.0 - commission)
    }

    func calculateEarnings(
        amount: Decimal,
        validatorAccountId: Data,
        isCompound: Bool,
        period: CalculationPeriod
    ) throws -> Decimal {
        guard let validator = validators.first(where: { $0.accountId == validatorAccountId }) else {
            throw RewardCalculatorEngineError.unexpectedValidator(accountId: validatorAccountId)
        }

        return calculateEarningsForValidator(validator, amount: amount, isCompound: isCompound, period: period)
    }

    func calculateMaxEarnings(amount: Decimal, isCompound: Bool, period: CalculationPeriod) -> Decimal {
        guard let validator = maxValidator else {
            return 0.0
        }

        return calculateEarningsForValidator(
            validator,
            amount: amount,
            isCompound: isCompound,
            period: period
        )
    }

    func calculateAvgEarnings(amount: Decimal, isCompound: Bool, period: CalculationPeriod) -> Decimal {
        calculateEarningsForAmount(
            amount,
            stake: averageStake,
            commission: medianCommission,
            isCompound: isCompound,
            period: period
        )
    }

    private func calculateEarningsForValidator(
        _ validator: EraValidatorInfo,
        amount: Decimal,
        isCompound: Bool,
        period: CalculationPeriod
    ) -> Decimal {
        let commission = Decimal.fromSubstratePerbill(value: validator.prefs.commission) ?? 0.0
        let stake = Decimal.fromSubstrateAmount(
            validator.exposure.total,
            precision: assetPrecision
        ) ?? 0.0

        return calculateEarningsForAmount(
            amount,
            stake: stake,
            commission: commission,
            isCompound: isCompound,
            period: period
        )
    }

    private func calculateEarningsForAmount(
        _ amount: Decimal,
        stake: Decimal,
        commission: Decimal,
        isCompound: Bool,
        period: CalculationPeriod
    ) -> Decimal {
        let annualReturn = calculateReturnForStake(stake, commission: commission)

        let eraInterestRate = calculateEraReturn(from: annualReturn)

        if isCompound {
            return calculateCompoundReward(
                initialAmount: amount,
                period: period,
                eraInterestRate: eraInterestRate
            )
        } else {
            return calculateSimpleReward(amount: amount, period: period, eraInterestRate: eraInterestRate)
        }
    }

    // MARK: - Private

    // Calculation formula: R = P(1 + r/n)^nt - P, where
    // P – original amount
    // r - daily interest rate
    // n - number of eras in a day
    // t - number of days
    private func calculateCompoundReward(
        initialAmount: Decimal,
        period: CalculationPeriod,
        eraInterestRate: Decimal
    ) -> Decimal {
        let numberOfDays = period.inDays

        guard eraDurationInSeconds > 0 else {
            return 0
        }

        let erasPerDay = TimeInterval.secondsInDay / eraDurationInSeconds

        guard erasPerDay > 0 else {
            return 0.0
        }

        let rawEraInterestRate = (eraInterestRate as NSDecimalNumber).doubleValue
        let compoundedInterest = pow(1.0 + rawEraInterestRate, erasPerDay * Double(numberOfDays))
        let finalAmount = initialAmount * Decimal(compoundedInterest)

        return finalAmount - initialAmount
    }

    private func calculateSimpleReward(
        amount: Decimal,
        period: CalculationPeriod,
        eraInterestRate: Decimal
    ) -> Decimal {
        guard eraDurationInSeconds > 0 else {
            return 0
        }

        let erasPerDay = TimeInterval.secondsInDay / eraDurationInSeconds
        return amount * eraInterestRate * Decimal(period.inDays) * Decimal(erasPerDay)
    }
}
