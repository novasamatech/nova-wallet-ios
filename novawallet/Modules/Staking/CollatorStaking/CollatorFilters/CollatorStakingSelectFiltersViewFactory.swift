import Foundation
import Foundation_iOS

struct CollatorStakingSelectFiltersViewFactory {
    static func createMythosStakingView(
        for sorting: CollatorsSortType,
        delegate: CollatorStakingSelectFiltersDelegate
    ) -> CollatorStakingSelectFiltersViewProtocol? {
        createView(
            for: sorting,
            supportedSortingTypes: [.rewards, .totalStake],
            delegate: delegate
        )
    }

    static func createParachainStakingView(
        for sorting: CollatorsSortType,
        delegate: CollatorStakingSelectFiltersDelegate
    ) -> CollatorStakingSelectFiltersViewProtocol? {
        createView(
            for: sorting,
            supportedSortingTypes: [.rewards, .minStake, .totalStake, .ownStake],
            delegate: delegate
        )
    }

    static func createView(
        for sorting: CollatorsSortType,
        supportedSortingTypes: [CollatorsSortType],
        delegate: CollatorStakingSelectFiltersDelegate
    ) -> CollatorStakingSelectFiltersViewProtocol? {
        let wireframe = CollatorStakingSelectFiltersWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = CollatorStakingSelectFiltersPresenter(
            wireframe: wireframe,
            sorting: sorting,
            sortingTypes: supportedSortingTypes,
            delegate: delegate,
            localizationManager: localizationManager
        )

        let view = CollatorStakingSelectFiltersViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view

        return view
    }
}
