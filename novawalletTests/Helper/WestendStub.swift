import Foundation
@testable import novawallet
import BigInt
import NovaCrypto

import SubstrateSdk

struct WestendStub {
    static let address: String = "5DnQFjSrJUiCnDb9mrbbCkGRXwKZc5v31M261PMMTTMFDawq"

    static let totalReward: TotalRewardItem = {
        TotalRewardItem(
            address: "5DnQFjSrJUiCnDb9mrbbCkGRXwKZc5v31M261PMMTTMFDawq",
            amount: AmountDecimal(value: 777)
        )
    }()

    static let activeEra: DecodedActiveEra = {
        let era = ActiveEraInfo(index: 777)
        return DecodedActiveEra(
            identifier: KnowChainId.westend + "_active_era",
            item: era
        )
    }()

    static let currentEra: DecodedEraIndex = {
        DecodedEraIndex(identifier: KnowChainId.westend + "_current_era", item: StringScaleMapper(value: 777))
    }()

    static let minNominatorBond: DecodedBigUInt = {
        DecodedBigUInt(
            identifier: KnowChainId.westend + "_minbond",
            item: StringScaleMapper(value: BigUInt(1e+12))
        )
    }()

    static let counterForNominators: DecodedU32 = {
        DecodedU32(
            identifier: KnowChainId.westend + "_counterForNominators",
            item: StringScaleMapper(value: 100)
        )
    }()

    static let maxNominatorsCount: DecodedU32 = {
        DecodedU32(
            identifier: KnowChainId.westend + "_maxNominatorsCount",
            item: StringScaleMapper(value: 1000)
        )
    }()

    static let nomination: DecodedNomination = {
        let nomination = Nomination(
            targets: [],
            submittedIn: 0
        )

        return DecodedNomination(
            identifier: "5EJQtTE1ZS9cBdqiuUcjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr6",
            item: nomination
        )
    }()

    static let ledgerInfo: DecodedLedgerInfo = {
        let address = "5DnQFjSrJUiCnDb9mrbbCkGRXwKZc5v31M261PMMTTMFDawq"
        let accountId = try! address.toAccountId()
        let info = StakingLedger(
            stash: accountId,
            total: BigUInt(1e+12),
            active: BigUInt(1e+12),
            unlocking: [],
            claimedRewards: [],
            legacyClaimedRewards: nil
        )

        return DecodedLedgerInfo(identifier: address, item: info)
    }()

    static let validator: DecodedValidator = {
        let prefs = ValidatorPrefs(commission: BigUInt(1e+8), blocked: false)

        return DecodedValidator(
            identifier: "5EJQtTE1ZS9cBdqiuUcjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr6",
            item: prefs
        )
    }()

    static let recommendedValidators: [ElectedValidatorInfo] = {
        let address = "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr6"
        let validator = ElectedValidatorInfo(
            address: address,
            nominators: [],
            totalStake: 10.0,
            ownStake: 10.0,
            comission: 0.1,
            identity: AccountIdentity(name: "Test"),
            stakeReturn: 0.1,
            hasSlashes: false,
            maxNominatorsRewarded: 128,
            blocked: false
        )
        return [validator]
    }()

    static let otherValidators: [ElectedValidatorInfo] = {
        let address = "5DnQFjSrJUiCnDb9mrbbCkGRXwKZc5v31M261PMMTTMFDawq"
        let validator = ElectedValidatorInfo(
            address: address,
            nominators: [],
            totalStake: 5.0,
            ownStake: 5.0,
            comission: 0.1,
            identity: nil,
            stakeReturn: 0.1,
            hasSlashes: true,
            maxNominatorsRewarded: 1000,
            blocked: false
        )
        return [validator]
    }()

    static var allValidators: [ElectedValidatorInfo] { otherValidators + recommendedValidators }

    static func activeValidators(
        for nominatorAddress: AccountAddress
    ) -> [SelectedValidatorInfo] {
        allValidators.map { electedValidator in
            let nominator = NominatorInfo(address: nominatorAddress, stake: 10.0)
            let validatorStakeInfo = ValidatorStakeInfo(
                nominators: [nominator],
                totalStake: 20.0,
                stakeReturn: 0.1,
                maxNominatorsRewarded: 128
            )
            return SelectedValidatorInfo(
                address: electedValidator.address,
                identity: electedValidator.identity,
                stakeInfo: validatorStakeInfo,
                myNomination: .active(allocation: ValidatorTokenAllocation(amount: 10.0, isRewarded: true))
            )
        }
    }

    static let eraValidators: [EraValidatorInfo] = {
        let validator = EraValidatorInfo(
            accountId: Data(repeating: 0, count: 32),
            exposure: Staking.ValidatorExposure(
                total: BigUInt(1e+13),
                own: BigUInt(1e+13),
                others: []
            ),
            prefs: ValidatorPrefs(commission: BigUInt(1e+8), blocked: false)
        )

        return [validator]
    }()

    static let rewardCalculator: RewardCalculatorEngineProtocol = {
        let total = eraValidators.reduce(BigUInt(0)) { $0 + $1.exposure.total }

        return InflationCurveRewardEngine(
            chainId: KnowChainId.westend,
            assetPrecision: 12,
            totalIssuance: total,
            validators: eraValidators,
            eraDurationInSeconds: 21600,
            config: InflationCurveRewardConfig(),
            parachainsCount: 0
        )
    }()
}
