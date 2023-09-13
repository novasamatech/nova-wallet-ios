import Foundation

struct ElectedAndPrefValidators {
    let electedValidators: [ElectedValidatorInfo]
    let preferredValidators: [SelectedValidatorInfo]

    func electedToSelectedValidators(for address: AccountAddress? = nil) -> [SelectedValidatorInfo] {
        electedValidators.map { $0.toSelected(for: address) }
    }
}
