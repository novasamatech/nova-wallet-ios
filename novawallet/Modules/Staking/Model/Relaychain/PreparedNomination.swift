import Foundation

struct PreparedNomination<T> {
    let bonding: T
    let targets: [SelectedValidatorInfo]
    let maxTargets: Int
}

struct PreparedValidators {
    let targets: [SelectedValidatorInfo]
    let maxTargets: Int
    let electedAndPrefValidators: ElectedAndPrefValidators
    let recommendedValidators: [SelectedValidatorInfo]
}
