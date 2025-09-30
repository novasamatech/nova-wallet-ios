import Foundation

struct EraStakersInfo {
    let activeEra: Staking.EraIndex
    let validators: [EraValidatorInfo]
}

struct EraValidatorInfo {
    let accountId: Data
    let exposure: Staking.ValidatorExposure
    let prefs: Staking.ValidatorPrefs
}
