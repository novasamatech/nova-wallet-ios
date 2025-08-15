import Foundation_iOS
import Keystore_iOS
import Operation_iOS
import SubstrateSdk

struct ValidatorSearchViewFactory {
    private static func createInteractor(
        chainAsset: ChainAsset,
        eraValidatorService: EraValidatorServiceProtocol,
        rewardCalculationService: RewardCalculatorServiceProtocol
    ) -> ValidatorSearchInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let identityProxyFactory = IdentityProxyFactory(
            originChain: chainAsset.chain,
            chainRegistry: chainRegistry,
            identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory)
        )

        let validatorOperationFactory = ValidatorOperationFactory(
            chainInfo: chainAsset.chainAssetInfo,
            eraValidatorService: eraValidatorService,
            rewardService: rewardCalculationService,
            storageRequestFactory: storageRequestFactory,
            runtimeService: runtimeService,
            engine: connection,
            identityProxyFactory: identityProxyFactory,
            slashesOperationFactory: SlashesOperationFactory(
                storageRequestFactory: storageRequestFactory,
                operationQueue: OperationManagerFacade.sharedDefaultQueue
            )
        )

        return ValidatorSearchInteractor(
            validatorOperationFactory: validatorOperationFactory,
            operationManager: OperationManagerFacade.sharedManager
        )
    }
}

extension ValidatorSearchViewFactory {
    static func createView(
        for state: RelaychainStakingSharedStateProtocol,
        validatorList: [SelectedValidatorInfo],
        selectedValidatorList: [SelectedValidatorInfo],
        delegate: ValidatorSearchDelegate?
    ) -> ValidatorSearchViewProtocol? {
        guard let interactor = createInteractor(
            chainAsset: state.stakingOption.chainAsset,
            eraValidatorService: state.eraValidatorService,
            rewardCalculationService: state.rewardCalculatorService
        ) else {
            return nil
        }

        let wireframe = ValidatorSearchWireframe(chainAsset: state.stakingOption.chainAsset)

        let viewModelFactory = ValidatorSearchViewModelFactory()

        let presenter = ValidatorSearchPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            fullValidatorList: validatorList,
            selectedValidatorList: selectedValidatorList,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        presenter.delegate = delegate
        interactor.presenter = presenter

        let view = ValidatorSearchViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }

    static func createView(
        startStakingState state: RelaychainStartStakingStateProtocol,
        validatorList: [SelectedValidatorInfo],
        selectedValidatorList: [SelectedValidatorInfo],
        delegate: ValidatorSearchDelegate?
    ) -> ValidatorSearchViewProtocol? {
        guard let interactor = createInteractor(
            chainAsset: state.chainAsset,
            eraValidatorService: state.eraValidatorService,
            rewardCalculationService: state.relaychainRewardCalculatorService
        ) else {
            return nil
        }

        let wireframe = ValidatorSearchWireframe(chainAsset: state.chainAsset)

        let viewModelFactory = ValidatorSearchViewModelFactory()

        let presenter = ValidatorSearchPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            fullValidatorList: validatorList,
            selectedValidatorList: selectedValidatorList,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        presenter.delegate = delegate
        interactor.presenter = presenter

        let view = ValidatorSearchViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
