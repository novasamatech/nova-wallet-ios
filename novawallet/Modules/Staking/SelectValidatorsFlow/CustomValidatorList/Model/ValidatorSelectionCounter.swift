import Foundation

// Counts are always expressed in community terms: locked validators are permanently
// selected, so the user only manages the remaining slots.
struct ValidatorSelectionState: Equatable {
    let communitySelected: Int
    let communityLimit: Int
    let lockedSelected: Int

    static let empty = ValidatorSelectionState(
        communitySelected: 0,
        communityLimit: 0,
        lockedSelected: 0
    )
}

struct ValidatorSelectionCounter {
    let lockedAddresses: Set<AccountAddress>
    let maxNominations: Int

    func state(for selected: [SelectedValidatorInfo]) -> ValidatorSelectionState {
        let lockedSelected = selected.filter { lockedAddresses.contains($0.address) }.count

        return .init(
            communitySelected: selected.count - lockedSelected,
            communityLimit: max(maxNominations - lockedSelected, 0),
            lockedSelected: lockedSelected
        )
    }
}
