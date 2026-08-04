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

extension ElectedAndPrefValidators {
    // Preferred validators a user may be locked into. Same eligibility rule
    // RecommendationsComposer applies to preferences, so "locked implies selected" holds.
    var lockedValidators: [SelectedValidatorInfo] {
        preferredValidators.filter { !$0.blocked && !$0.oversubscribed }
    }
}
