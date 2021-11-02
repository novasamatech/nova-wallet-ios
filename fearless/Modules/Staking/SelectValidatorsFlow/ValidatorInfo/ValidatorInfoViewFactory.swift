import Foundation
import SubstrateSdk
import SoraKeystore
import SoraFoundation

final class ValidatorInfoViewFactory {
    private static func createView(
        with interactor: ValidatorInfoInteractorBase,
        assetInfo: AssetBalanceDisplayInfo
    ) -> ValidatorInfoViewProtocol? {
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let validatorInfoViewModelFactory = ValidatorInfoViewModelFactory(
            iconGenerator: PolkadotIconGenerator(),
            balanceViewModelFactory: balanceViewModelFactory
        )

        let wireframe = ValidatorInfoWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = ValidatorInfoPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: validatorInfoViewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = ValidatorInfoViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}

extension ValidatorInfoViewFactory {
    static func createView(
        with validatorInfo: ValidatorInfoProtocol,
        state: StakingSharedState
    ) -> ValidatorInfoViewProtocol? {
        guard let chainAsset = state.settings.value else { return nil }

        let interactor = AnyValidatorInfoInteractor(
            selectedAsset: chainAsset.asset,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            validatorInfo: validatorInfo
        )

        return createView(with: interactor, assetInfo: chainAsset.assetDisplayInfo)
    }

    static func createView(
        with accountAddress: AccountAddress,
        state: StakingSharedState
    ) -> ValidatorInfoViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let chainAsset = state.settings.value,
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId)
        else { return nil }

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let validatorOperationFactory = ValidatorOperationFactory(
            chainInfo: chainAsset.chainAssetInfo,
            eraValidatorService: state.eraValidatorService,
            rewardService: state.rewardCalculationService,
            storageRequestFactory: storageRequestFactory,
            runtimeService: runtimeService,
            engine: connection,
            identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory)
        )

        let interactor = YourValidatorInfoInteractor(
            accountAddress: accountAddress,
            selectedAsset: chainAsset.asset,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            validatorOperationFactory: validatorOperationFactory,
            operationManager: OperationManagerFacade.sharedManager
        )

        return createView(with: interactor, assetInfo: chainAsset.assetDisplayInfo)
    }
}
