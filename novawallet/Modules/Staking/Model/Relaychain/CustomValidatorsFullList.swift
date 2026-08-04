import Foundation

struct CustomValidatorsFullList {
    let allValidators: [SelectedValidatorInfo]
    let preferredValidators: [SelectedValidatorInfo]

    func distinctCount() -> Int {
        distinctAll().count
    }

    func distinctAll() -> [SelectedValidatorInfo] {
        let allValidatorAddresses = Set(allValidators.map(\.address))

        return allValidators + preferredValidators.filter { !allValidatorAddresses.contains($0.address) }
    }
}

extension CustomValidatorsFullList {
    // Within the selection flow preferredValidators is already the eligible lock set,
    // built from ElectedAndPrefValidators.lockedValidators.
    var lockedAddresses: Set<AccountAddress> {
        Set(preferredValidators.map(\.address))
    }
}
