import Foundation
import Foundation_iOS
import SubstrateSdk

final class RecommendedValidatorListViewFactory {
    static func createInitiatedBondingView(
        stakingState: RelaychainStakingSharedStateProtocol,
        validators: [SelectedValidatorInfo],
        maxTargets: Int,
        state: InitiatedBonding
    ) -> RecommendedValidatorListViewProtocol? {
        let wireframe = InitiatedBondingRecommendationWireframe(state: state, stakingState: stakingState)
        return createView(for: validators, maxTargets: maxTargets, with: wireframe)
    }

    static func createChangeTargetsView(
        stakingState: RelaychainStakingSharedStateProtocol,
        validators: [SelectedValidatorInfo],
        maxTargets: Int,
        state: ExistingBonding
    ) -> RecommendedValidatorListViewProtocol? {
        let wireframe = ChangeTargetsRecommendationWireframe(state: state, stakingState: stakingState)
        return createView(for: validators, maxTargets: maxTargets, with: wireframe)
    }

    static func createChangeYourValidatorsView(
        stakingState: RelaychainStakingSharedStateProtocol,
        validators: [SelectedValidatorInfo],
        maxTargets: Int,
        state: ExistingBonding
    ) -> RecommendedValidatorListViewProtocol? {
        let wireframe = YourValidatorList.RecommendationWireframe(state: state, stakingState: stakingState)
        return createView(for: validators, maxTargets: maxTargets, with: wireframe)
    }

    static func createView(
        for validators: [SelectedValidatorInfo],
        maxTargets: Int,
        with wireframe: RecommendedValidatorListWireframeProtocol
    ) -> RecommendedValidatorListViewProtocol? {
        let viewModelFactory = RecommendedValidatorListViewModelFactory(
            iconGenerator: PolkadotIconGenerator()
        )

        let presenter = RecommendedValidatorListPresenter(
            viewModelFactory: viewModelFactory,
            validators: validators,
            maxTargets: maxTargets,
            logger: Logger.shared
        )

        let view = RecommendedValidatorListViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        presenter.wireframe = wireframe

        view.localizationManager = LocalizationManager.shared

        return view
    }
}
