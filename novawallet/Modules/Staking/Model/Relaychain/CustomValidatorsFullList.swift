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
