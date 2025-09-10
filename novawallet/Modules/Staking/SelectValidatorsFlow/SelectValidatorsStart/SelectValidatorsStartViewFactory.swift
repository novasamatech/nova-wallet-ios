import Foundation
import SubstrateSdk
import Keystore_iOS
import Foundation_iOS
import Operation_iOS

final class SelectValidatorsStartViewFactory {
    static func createInitiatedBondingView(
        with state: InitiatedBonding,
        stakingState: RelaychainStakingSharedStateProtocol
    ) -> SelectValidatorsStartViewProtocol? {
        let wireframe = InitBondSelectValidatorsStartWireframe(state: state, stakingState: stakingState)
        return createView(
            with: wireframe,
            existingStashAddress: nil,
            selectedValidators: nil,
            amount: state.amount,
            stakingState: stakingState
        )
    }

    static func createChangeTargetsView(
        with state: ExistingBonding,
        stakingState: RelaychainStakingSharedStateProtocol
    ) -> SelectValidatorsStartViewProtocol? {
        let wireframe = ChangeTargetsSelectValidatorsStartWireframe(
            state: state,
            stakingState: stakingState
        )

        return createView(
            with: wireframe,
            existingStashAddress: state.stashAddress,
            selectedValidators: state.selectedTargets,
            amount: state.amount,
            stakingState: stakingState
        )
    }

    static func createChangeYourValidatorsView(
        with state: ExistingBonding,
        stakingState: RelaychainStakingSharedStateProtocol
    ) -> SelectValidatorsStartViewProtocol? {
        let wireframe = YourValidatorList.SelectionStartWireframe(state: state, stakingState: stakingState)
        return createView(
            with: wireframe,
            existingStashAddress: state.stashAddress,
            selectedValidators: state.selectedTargets,
            amount: state.amount,
            stakingState: stakingState
        )
    }

    private static func createView(
        with wireframe: SelectValidatorsStartWireframeProtocol,
        existingStashAddress: AccountAddress?,
        selectedValidators: [SelectedValidatorInfo]?,
        amount: Decimal,
        stakingState: RelaychainStakingSharedStateProtocol
    ) -> SelectValidatorsStartViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let chainAsset = stakingState.stakingOption.chainAsset

        guard
            let stakingAmount = amount.toSubstrateAmount(precision: chainAsset.assetDisplayInfo.assetPrecision),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let eraValidatorService = stakingState.eraValidatorService
        let rewardCalculationService = stakingState.rewardCalculatorService

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let operationManager = OperationManager(operationQueue: operationQueue)

        let storageOperationFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let identityOperationFactory = IdentityOperationFactory(requestFactory: storageOperationFactory)
        let identityProxyFactory = IdentityProxyFactory(
            originChain: chainAsset.chain,
            chainRegistry: chainRegistry,
            identityOperationFactory: identityOperationFactory
        )

        let operationFactory = ValidatorOperationFactory(
            chainInfo: chainAsset.chainAssetInfo,
            eraValidatorService: eraValidatorService,
            rewardService: rewardCalculationService,
            storageRequestFactory: storageOperationFactory,
            runtimeService: runtimeService,
            engine: connection,
            identityProxyFactory: identityProxyFactory
        )

        let maxNominationsFactory = MaxNominationsOperationFactory(operationQueue: operationQueue)

        let interactor = SelectValidatorsStartInteractor(
            chain: chainAsset.chain,
            runtimeService: runtimeService,
            connection: connection,
            operationFactory: operationFactory,
            maxNominationsOperationFactory: maxNominationsFactory,
            operationQueue: operationQueue,
            preferredValidatorsProvider: stakingState.preferredValidatorsProvider,
            stakingAmount: stakingAmount
        )

        let presenter = SelectValidatorsStartPresenter(
            interactor: interactor,
            wireframe: wireframe,
            existingStashAddress: existingStashAddress,
            initialTargets: selectedValidators,
            applicationConfig: ApplicationConfig.shared,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = SelectValidatorsStartViewController(
            presenter: presenter,
            phase: selectedValidators == nil ? .setup : .update,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
