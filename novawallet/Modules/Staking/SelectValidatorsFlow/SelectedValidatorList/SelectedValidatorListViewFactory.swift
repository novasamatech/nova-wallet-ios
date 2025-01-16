import Foundation
import Foundation_iOS

struct SelectedValidatorListViewFactory {
    static func createInitiatedBondingView(
        stakingState: RelaychainStakingSharedStateProtocol,
        validatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        delegate: SelectedValidatorListDelegate,
        state: InitiatedBonding
    ) -> SelectedValidatorListViewProtocol? {
        let wireframe = InitiatedBondingSelectedValidatorListWireframe(state: state, stakingState: stakingState)
        return createView(
            validatorList: validatorList,
            maxTargets: maxTargets,
            delegate: delegate,
            wireframe: wireframe
        )
    }

    static func createChangeTargetsView(
        stakingState: RelaychainStakingSharedStateProtocol,
        validatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        delegate: SelectedValidatorListDelegate,
        state: ExistingBonding
    ) -> SelectedValidatorListViewProtocol? {
        let wireframe = ChangeTargetsSelectedValidatorListWireframe(state: state, stakingState: stakingState)
        return createView(
            validatorList: validatorList,
            maxTargets: maxTargets,
            delegate: delegate,
            wireframe: wireframe
        )
    }

    static func createChangeYourValidatorsView(
        stakingState: RelaychainStakingSharedStateProtocol,
        validatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        delegate: SelectedValidatorListDelegate,
        state: ExistingBonding
    ) -> SelectedValidatorListViewProtocol? {
        let wireframe = YourValidatorList.SelectedListWireframe(state: state, stakingState: stakingState)
        return createView(
            validatorList: validatorList,
            maxTargets: maxTargets,
            delegate: delegate,
            wireframe: wireframe
        )
    }

    static func createView(
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

    static func createStartStakingView(
        startStakingState: RelaychainStartStakingStateProtocol,
        validatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        delegate: SelectedValidatorListDelegate,
        stakingSelectValidatorsDelegate: StakingSelectValidatorsDelegateProtocol?
    ) -> SelectedValidatorListViewProtocol? {
        let wireframe = StartStakingSelectedValidatorsListWireframe(
            state: startStakingState,
            delegate: stakingSelectValidatorsDelegate
        )
        return createView(
            validatorList: validatorList,
            maxTargets: maxTargets,
            delegate: delegate,
            wireframe: wireframe
        )
    }
}
