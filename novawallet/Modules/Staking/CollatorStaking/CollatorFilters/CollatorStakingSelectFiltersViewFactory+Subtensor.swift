import Foundation
import Foundation_iOS

extension CollatorStakingSelectFiltersViewFactory {
    static func createSubtensorStakingView(
        for sorting: CollatorsSortType,
        delegate: CollatorStakingSelectFiltersDelegate
    ) -> CollatorStakingSelectFiltersViewProtocol? {
        createView(
            for: sorting,
            supportedSortingTypes: [.totalStake, .ownStake],
            defaultSorting: .totalStake,
            delegate: delegate
        )
    }
}
