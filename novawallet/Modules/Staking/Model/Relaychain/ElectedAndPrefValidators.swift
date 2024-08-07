import Foundation

struct ElectedAndPrefValidators: Equatable {
    let allElectedValidators: [ElectedValidatorInfo]
    let notExcludedElectedValidators: [ElectedValidatorInfo]
    let preferredValidators: [SelectedValidatorInfo]

    func notExcludedElectedToSelectedValidators(for address: AccountAddress? = nil) -> [SelectedValidatorInfo] {
        notExcludedElectedValidators.map { $0.toSelected(for: address) }
    }

    func allElectedToSelectedValidators(for address: AccountAddress? = nil) -> [SelectedValidatorInfo] {
        allElectedValidators.map { $0.toSelected(for: address) }
    }
}
