import Foundation

struct ValidatorSelectionState: Equatable {
    let communitySelected: Int
    let communityLimit: Int
    let lockedSelected: Int
    let totalLimit: Int

    var totalSelected: Int { communitySelected + lockedSelected }

    static let empty = ValidatorSelectionState(
        communitySelected: 0,
        communityLimit: 0,
        lockedSelected: 0,
        totalLimit: 0
    )
}

struct ValidatorSelectionCounter {
    let lockedAddresses: Set<AccountAddress>
    let maxNominations: Int

    func state(for selected: [SelectedValidatorInfo]) -> ValidatorSelectionState {
        let lockedSelected = selected.filter { lockedAddresses.contains($0.address) }.count

        return .init(
            communitySelected: selected.count - lockedSelected,
            communityLimit: max(maxNominations - lockedAddresses.count, 0),
            lockedSelected: lockedSelected,
            totalLimit: maxNominations
        )
    }
}
