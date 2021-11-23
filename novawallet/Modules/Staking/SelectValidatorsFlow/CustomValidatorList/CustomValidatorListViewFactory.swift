import Foundation
import SoraFoundation
import SoraKeystore

enum CustomValidatorListViewFactory {
    private static func createView(
        for stakingState: StakingSharedState,
        validatorList: [SelectedValidatorInfo],
        recommendedValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        maxTargets: Int,
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
            fullValidatorList: validatorList,
            recommendedValidatorList: recommendedValidatorList,
            selectedValidatorList: selectedValidatorList,
            maxTargets: maxTargets,
            logger: Logger.shared
        )

        let view = CustomValidatorListViewController(
            presenter: presenter,
            selectedValidatorsLimit: maxTargets,
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
        validatorList: [SelectedValidatorInfo],
        recommendedValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        maxTargets: Int,
        state: InitiatedBonding
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = InitBondingCustomValidatorListWireframe(state: state, stakingState: stakingState)
        return createView(
            for: stakingState,
            validatorList: validatorList,
            recommendedValidatorList: recommendedValidatorList,
            selectedValidatorList: selectedValidatorList,
            maxTargets: maxTargets,
            wireframe: wireframe
        )
    }

    static func createChangeTargetsView(
        for stakingState: StakingSharedState,
        validatorList: [SelectedValidatorInfo],
        recommendedValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        maxTargets: Int,
        state: ExistingBonding
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = ChangeTargetsCustomValidatorListWireframe(state: state, stakingState: stakingState)
        return createView(
            for: stakingState,
            validatorList: validatorList,
            recommendedValidatorList: recommendedValidatorList,
            selectedValidatorList: selectedValidatorList,
            maxTargets: maxTargets,
            wireframe: wireframe
        )
    }

    static func createChangeYourValidatorsView(
        for stakingState: StakingSharedState,
        validatorList: [SelectedValidatorInfo],
        recommendedValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        maxTargets: Int,
        state: ExistingBonding
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = YourValidatorList.CustomListWireframe(state: state, stakingState: stakingState)
        return createView(
            for: stakingState,
            validatorList: validatorList,
            recommendedValidatorList: recommendedValidatorList,
            selectedValidatorList: selectedValidatorList,
            maxTargets: maxTargets,
            wireframe: wireframe
        )
    }
}
