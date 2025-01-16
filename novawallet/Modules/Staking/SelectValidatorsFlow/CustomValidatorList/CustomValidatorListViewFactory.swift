import Foundation
import Foundation_iOS
import Keystore_iOS

enum CustomValidatorListViewFactory {
    private static func createView(
        chainAsset: ChainAsset,
        selectionValidatorGroups: SelectionValidatorGroups,
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        validatorsSelectionParams: ValidatorsSelectionParams,
        wireframe: CustomValidatorListWireframeProtocol
    ) -> CustomValidatorListViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = CustomValidatorListInteractor(
            selectedAsset: chainAsset.asset,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager
        )
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

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
        for stakingState: RelaychainStakingSharedStateProtocol,
        selectionValidatorGroups: SelectionValidatorGroups,
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        validatorsSelectionParams: ValidatorsSelectionParams,
        state: InitiatedBonding
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = InitBondingCustomValidatorListWireframe(state: state, stakingState: stakingState)
        return createView(
            chainAsset: stakingState.stakingOption.chainAsset,
            selectionValidatorGroups: selectionValidatorGroups,
            selectedValidatorList: selectedValidatorList,
            validatorsSelectionParams: validatorsSelectionParams,
            wireframe: wireframe
        )
    }

    static func createValidatorListView(
        for stakingState: RelaychainStartStakingStateProtocol,
        selectionValidatorGroups: SelectionValidatorGroups,
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        validatorsSelectionParams: ValidatorsSelectionParams,
        delegate: StakingSelectValidatorsDelegateProtocol?
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = StartStakingCustomValidatorListWireframe(
            stakingState: stakingState,
            delegate: delegate
        )
        return createView(
            chainAsset: stakingState.chainAsset,
            selectionValidatorGroups: selectionValidatorGroups,
            selectedValidatorList: selectedValidatorList,
            validatorsSelectionParams: validatorsSelectionParams,
            wireframe: wireframe
        )
    }

    static func createChangeTargetsView(
        for stakingState: RelaychainStakingSharedStateProtocol,
        selectionValidatorGroups: SelectionValidatorGroups,
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        validatorsSelectionParams: ValidatorsSelectionParams,
        state: ExistingBonding
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = ChangeTargetsCustomValidatorListWireframe(state: state, stakingState: stakingState)
        return createView(
            chainAsset: stakingState.stakingOption.chainAsset,
            selectionValidatorGroups: selectionValidatorGroups,
            selectedValidatorList: selectedValidatorList,
            validatorsSelectionParams: validatorsSelectionParams,
            wireframe: wireframe
        )
    }

    static func createChangeYourValidatorsView(
        for stakingState: RelaychainStakingSharedStateProtocol,
        selectionValidatorGroups: SelectionValidatorGroups,
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        validatorsSelectionParams: ValidatorsSelectionParams,
        state: ExistingBonding
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = YourValidatorList.CustomListWireframe(state: state, stakingState: stakingState)
        return createView(
            chainAsset: stakingState.stakingOption.chainAsset,
            selectionValidatorGroups: selectionValidatorGroups,
            selectedValidatorList: selectedValidatorList,
            validatorsSelectionParams: validatorsSelectionParams,
            wireframe: wireframe
        )
    }
}
