import Foundation
import SoraFoundation

struct ParaStkCollatorFiltersViewFactory {
    static func createMythosStakingView(
        for sorting: CollatorsSortType,
        delegate: ParaStkCollatorFiltersDelegate
    ) -> ParaStkCollatorFiltersViewProtocol? {
        createView(
            for: sorting,
            supportedSortingTypes: [.rewards, .totalStake],
            delegate: delegate
        )
    }

    static func createParachainStakingView(
        for sorting: CollatorsSortType,
        delegate: ParaStkCollatorFiltersDelegate
    ) -> ParaStkCollatorFiltersViewProtocol? {
        createView(
            for: sorting,
            supportedSortingTypes: [.rewards, .minStake, .totalStake, .ownStake],
            delegate: delegate
        )
    }

    static func createView(
        for sorting: CollatorsSortType,
        supportedSortingTypes: [CollatorsSortType],
        delegate: ParaStkCollatorFiltersDelegate
    ) -> ParaStkCollatorFiltersViewProtocol? {
        let wireframe = ParaStkCollatorFiltersWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = ParaStkCollatorFiltersPresenter(
            wireframe: wireframe,
            sorting: sorting,
            sortingTypes: supportedSortingTypes,
            delegate: delegate,
            localizationManager: localizationManager
        )

        let view = ParaStkCollatorFiltersViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view

        return view
    }
}
