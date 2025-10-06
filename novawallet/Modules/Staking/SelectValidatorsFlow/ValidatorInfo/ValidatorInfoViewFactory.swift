import Foundation
import SubstrateSdk
import Keystore_iOS
import Foundation_iOS

final class ValidatorInfoViewFactory {
    private static func createView(
        with interactor: ValidatorInfoInteractorBase,
        assetInfo: AssetBalanceDisplayInfo,
        chain: ChainModel
    ) -> ValidatorInfoViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let validatorInfoViewModelFactory = ValidatorInfoViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory
        )

        let wireframe = ValidatorInfoWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = ValidatorInfoPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: validatorInfoViewModelFactory,
            localizationManager: localizationManager,
            chain: chain,
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
        state: RelaychainStakingSharedStateProtocol
    ) -> ValidatorInfoViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        return createView(with: validatorInfo, chainAsset: chainAsset)
    }

    static func createView(
        with validatorInfo: ValidatorInfoProtocol,
        chainAsset: ChainAsset
    ) -> ValidatorInfoViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else { return nil }

        let interactor = AnyValidatorInfoInteractor(
            selectedAsset: chainAsset.asset,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            validatorInfo: validatorInfo,
            currencyManager: currencyManager
        )

        return createView(
            with: interactor,
            assetInfo: chainAsset.assetDisplayInfo,
            chain: chainAsset.chain
        )
    }

    static func createView(
        with accountAddress: AccountAddress,
        state: RelaychainStakingSharedStateProtocol
    ) -> ValidatorInfoViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let chainAsset = state.stakingOption.chainAsset

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let currencyManager = CurrencyManager.shared
        else { return nil }

        let eraValidatorService = state.eraValidatorService
        let rewardCalculationService = state.rewardCalculatorService

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

        let interactor = YourValidatorInfoInteractor(
            accountAddress: accountAddress,
            selectedAsset: chainAsset.asset,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            validatorOperationFactory: validatorOperationFactory,
            operationManager: OperationManagerFacade.sharedManager,
            currencyManager: currencyManager
        )

        return createView(
            with: interactor,
            assetInfo: chainAsset.assetDisplayInfo,
            chain: chainAsset.chain
        )
    }
}
