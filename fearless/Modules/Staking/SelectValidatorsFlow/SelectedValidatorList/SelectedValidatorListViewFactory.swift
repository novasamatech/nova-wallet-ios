import Foundation
import SoraFoundation

struct SelectedValidatorListViewFactory {
    static func createInitiatedBondingView(
        stakingState: StakingSharedState,
        validatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        delegate: SelectedValidatorListDelegate,
        state: InitiatedBonding
    ) -> SelectedValidatorListViewProtocol? {
        let wireframe = InitiatedBondingSelectedValidatorListWireframe(state: state, stakingState: stakingState)
        return createView(
            stakingState: stakingState,
            validatorList: validatorList,
            maxTargets: maxTargets,
            delegate: delegate,
            wireframe: wireframe
        )
    }

    static func createChangeTargetsView(
        stakingState: StakingSharedState,
        validatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        delegate: SelectedValidatorListDelegate,
        state: ExistingBonding
    ) -> SelectedValidatorListViewProtocol? {
        let wireframe = ChangeTargetsSelectedValidatorListWireframe(state: state, stakingState: stakingState)
        return createView(
            stakingState: stakingState,
            validatorList: validatorList,
            maxTargets: maxTargets,
            delegate: delegate,
            wireframe: wireframe
        )
    }

    static func createChangeYourValidatorsView(
        stakingState: StakingSharedState,
        validatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        delegate: SelectedValidatorListDelegate,
        state: ExistingBonding
    ) -> SelectedValidatorListViewProtocol? {
        let wireframe = YourValidatorList.SelectedListWireframe(state: state, stakingState: stakingState)
        return createView(
            stakingState: stakingState,
            validatorList: validatorList,
            maxTargets: maxTargets,
            delegate: delegate,
            wireframe: wireframe
        )
    }

    static func createView(
        stakingState _: StakingSharedState,
        validatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        delegate: SelectedValidatorListDelegate,
        wireframe: SelectedValidatorListWireframeProtocol
    ) -> SelectedValidatorListViewProtocol? {
        let viewModelFactory = SelectedValidatorListViewModelFactory()

        let presenter = SelectedValidatorListPresenter(
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            selectedValidatorList: validatorList,
            maxTargets: maxTargets
        )

        presenter.delegate = delegate

        let view = SelectedValidatorListViewController(
            presenter: presenter,
            selectedValidatorsLimit: maxTargets,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
