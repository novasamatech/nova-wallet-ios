import Foundation
import SoraFoundation
import SoraKeystore

enum CustomValidatorListViewFactory {
    private static func createView(
        for stakingState: StakingSharedState,
        selectionValidatorGroups: SelectionValidatorGroups,
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        validatorsSelectionParams: ValidatorsSelectionParams,
        wireframe: CustomValidatorListWireframeProtocol
    ) -> CustomValidatorListViewProtocol? {
        guard let chainAsset = stakingState.settings.value else {
            return nil
        }

        let interactor = CustomValidatorListInteractor(
            selectedAsset: chainAsset.asset,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared
        )

        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: chainAsset.assetDisplayInfo)

        let viewModelFactory = CustomValidatorListViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory
        )

        let presenter = CustomValidatorListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            fullValidatorList: selectionValidatorGroups.fullValidatorList,
            recommendedValidatorList: selectionValidatorGroups.recommendedValidatorList,
            selectedValidatorList: selectedValidatorList,
            validatorsSelectionParams: validatorsSelectionParams,
            logger: Logger.shared
        )

        let view = CustomValidatorListViewController(
            presenter: presenter,
            selectedValidatorsLimit: validatorsSelectionParams.maxNominations,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}

extension CustomValidatorListViewFactory {
    static func createInitiatedBondingView(
        for stakingState: StakingSharedState,
        selectionValidatorGroups: SelectionValidatorGroups,
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        validatorsSelectionParams: ValidatorsSelectionParams,
        state: InitiatedBonding
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = InitBondingCustomValidatorListWireframe(state: state, stakingState: stakingState)
        return createView(
            for: stakingState,
            selectionValidatorGroups: selectionValidatorGroups,
            selectedValidatorList: selectedValidatorList,
            validatorsSelectionParams: validatorsSelectionParams,
            wireframe: wireframe
        )
    }

    static func createChangeTargetsView(
        for stakingState: StakingSharedState,
        selectionValidatorGroups: SelectionValidatorGroups,
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        validatorsSelectionParams: ValidatorsSelectionParams,
        state: ExistingBonding
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = ChangeTargetsCustomValidatorListWireframe(state: state, stakingState: stakingState)
        return createView(
            for: stakingState,
            selectionValidatorGroups: selectionValidatorGroups,
            selectedValidatorList: selectedValidatorList,
            validatorsSelectionParams: validatorsSelectionParams,
            wireframe: wireframe
        )
    }

    static func createChangeYourValidatorsView(
        for stakingState: StakingSharedState,
        selectionValidatorGroups: SelectionValidatorGroups,
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        validatorsSelectionParams: ValidatorsSelectionParams,
        state: ExistingBonding
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = YourValidatorList.CustomListWireframe(state: state, stakingState: stakingState)
        return createView(
            for: stakingState,
            selectionValidatorGroups: selectionValidatorGroups,
            selectedValidatorList: selectedValidatorList,
            validatorsSelectionParams: validatorsSelectionParams,
            wireframe: wireframe
        )
    }
}
