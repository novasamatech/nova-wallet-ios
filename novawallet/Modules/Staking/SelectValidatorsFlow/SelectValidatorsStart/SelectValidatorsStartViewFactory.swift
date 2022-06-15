import Foundation
import SubstrateSdk
import SoraKeystore
import SoraFoundation

final class SelectValidatorsStartViewFactory {
    static func createInitiatedBondingView(
        with state: InitiatedBonding,
        stakingState: StakingSharedState
    ) -> SelectValidatorsStartViewProtocol? {
        let wireframe = InitBondSelectValidatorsStartWireframe(state: state, stakingState: stakingState)
        return createView(
            with: wireframe,
            existingStashAddress: nil,
            selectedValidators: nil,
            stakingState: stakingState
        )
    }

    static func createChangeTargetsView(
        with state: ExistingBonding,
        stakingState: StakingSharedState
    ) -> SelectValidatorsStartViewProtocol? {
        let wireframe = ChangeTargetsSelectValidatorsStartWireframe(
            state: state,
            stakingState: stakingState
        )

        return createView(
            with: wireframe,
            existingStashAddress: state.stashAddress,
            selectedValidators: state.selectedTargets,
            stakingState: stakingState
        )
    }

    static func createChangeYourValidatorsView(
        with state: ExistingBonding,
        stakingState: StakingSharedState
    ) -> SelectValidatorsStartViewProtocol? {
        let wireframe = YourValidatorList.SelectionStartWireframe(state: state, stakingState: stakingState)
        return createView(
            with: wireframe,
            existingStashAddress: state.stashAddress,
            selectedValidators: state.selectedTargets,
            stakingState: stakingState
        )
    }

    private static func createView(
        with wireframe: SelectValidatorsStartWireframeProtocol,
        existingStashAddress: AccountAddress?,
        selectedValidators: [SelectedValidatorInfo]?,
        stakingState: StakingSharedState
    ) -> SelectValidatorsStartViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let chainAsset = stakingState.settings.value,
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let eraValidatorService = stakingState.eraValidatorService,
            let rewardCalculationService = stakingState.rewardCalculationService else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager
        let storageOperationFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let identityOperationFactory = IdentityOperationFactory(requestFactory: storageOperationFactory)

        let operationFactory = ValidatorOperationFactory(
            chainInfo: chainAsset.chainAssetInfo,
            eraValidatorService: eraValidatorService,
            rewardService: rewardCalculationService,
            storageRequestFactory: storageOperationFactory,
            runtimeService: runtimeService,
            engine: connection,
            identityOperationFactory: identityOperationFactory
        )

        let interactor = SelectValidatorsStartInteractor(
            runtimeService: runtimeService,
            operationFactory: operationFactory,
            operationManager: operationManager
        )

        let presenter = SelectValidatorsStartPresenter(
            interactor: interactor,
            wireframe: wireframe,
            existingStashAddress: existingStashAddress,
            initialTargets: selectedValidators,
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )

        let view = SelectValidatorsStartViewController(
            presenter: presenter,
            phase: selectedValidators == nil ? .setup : .update,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        return view
    }
}
