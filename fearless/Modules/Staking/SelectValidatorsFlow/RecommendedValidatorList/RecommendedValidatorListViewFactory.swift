import Foundation
import SoraFoundation
import SubstrateSdk

final class RecommendedValidatorListViewFactory {
    static func createInitiatedBondingView(
        stakingState: StakingSharedState,
        validators: [SelectedValidatorInfo],
        maxTargets: Int,
        state: InitiatedBonding
    ) -> RecommendedValidatorListViewProtocol? {
        let wireframe = InitiatedBondingRecommendationWireframe(state: state, stakingState: stakingState)
        return createView(for: validators, maxTargets: maxTargets, with: wireframe)
    }

    static func createChangeTargetsView(
        stakingState: StakingSharedState,
        validators: [SelectedValidatorInfo],
        maxTargets: Int,
        state: ExistingBonding
    ) -> RecommendedValidatorListViewProtocol? {
        let wireframe = ChangeTargetsRecommendationWireframe(state: state, stakingState: stakingState)
        return createView(for: validators, maxTargets: maxTargets, with: wireframe)
    }

    static func createChangeYourValidatorsView(
        stakingState: StakingSharedState,
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
        let view = RecommendedValidatorListViewController(nib: R.nib.recommendedValidatorListViewController)

        let viewModelFactory = RecommendedValidatorListViewModelFactory(
            iconGenerator: PolkadotIconGenerator()
        )

        let presenter = RecommendedValidatorListPresenter(
            viewModelFactory: viewModelFactory,
            validators: validators,
            maxTargets: maxTargets,
            logger: Logger.shared
        )

        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe

        view.localizationManager = LocalizationManager.shared

        return view
    }
}
