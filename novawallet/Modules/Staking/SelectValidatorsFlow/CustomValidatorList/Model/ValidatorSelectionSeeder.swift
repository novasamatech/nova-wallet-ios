import Foundation

enum ValidatorSelectionSeeder {
    // Locked validators occupy slots inside maxNominations, not on top of it: an existing
    // nomination at the cap loses its lowest ranked community picks to make room.
    static func seed(
        initialTargets: [SelectedValidatorInfo],
        lockedValidators: [SelectedValidatorInfo],
        maxNominations: Int
    ) -> [SelectedValidatorInfo] {
        let locked = Array(lockedValidators.prefix(maxNominations))
        let lockedAddresses = Set(locked.map(\.address))
        let communityLimit = max(maxNominations - locked.count, 0)

        let community = initialTargets
            .filter { !lockedAddresses.contains($0.address) }
            .sorted { $0.stakeReturn > $1.stakeReturn }
            .prefix(communityLimit)

        return Array(community) + locked
    }
}
