import Foundation
import SoraKeystore
import SoraFoundation
import FearlessUtils
import IrohaCrypto

final class StakingRewardPayoutsViewFactory {
    static func createViewForNominator(
        for state: StakingSharedState,
        stashAddress: AccountAddress
    ) -> StakingRewardPayoutsViewProtocol? {
        guard
            let chainAsset = state.settings.value,
            let rewardsUrl = chainAsset.chain.externalApi?.staking?.url else {
            return nil
        }

        let addressFactory = SS58AddressFactory()

        let validatorsResolutionFactory = PayoutValidatorsForNominatorFactory(
            url: rewardsUrl,
            addressFactory: addressFactory
        )

        let payoutInfoFactory = NominatorPayoutInfoFactory(chainAssetInfo: chainAsset.chainAssetInfo)

        return createView(
            for: state,
            stashAddress: stashAddress,
            validatorsResolutionFactory: validatorsResolutionFactory,
            payoutInfoFactory: payoutInfoFactory
        )
    }

    static func createViewForValidator(
        for state: StakingSharedState,
        stashAddress: AccountAddress
    ) -> StakingRewardPayoutsViewProtocol? {
        guard let chainAsset = state.settings.value else {
            return nil
        }

        let validatorsResolutionFactory = PayoutValidatorsForValidatorFactory()

        let payoutInfoFactory = ValidatorPayoutInfoFactory(chainAssetInfo: chainAsset.chainAssetInfo)

        return createView(
            for: state,
            stashAddress: stashAddress,
            validatorsResolutionFactory: validatorsResolutionFactory,
            payoutInfoFactory: payoutInfoFactory
        )
    }

    private static func createView(
        for state: StakingSharedState,
        stashAddress: AccountAddress,
        validatorsResolutionFactory: PayoutValidatorsFactoryProtocol,
        payoutInfoFactory: PayoutInfoFactoryProtocol
    ) -> StakingRewardPayoutsViewProtocol? {
        guard let chainAsset = state.settings.value else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let identityOperationFactory = IdentityOperationFactory(requestFactory: storageRequestFactory)

        let payoutService = PayoutRewardsService(
            selectedAccountAddress: stashAddress,
            chainFormat: chainAsset.chain.chainFormat,
            validatorsResolutionFactory: validatorsResolutionFactory,
            runtimeCodingService: runtimeService,
            storageRequestFactory: storageRequestFactory,
            engine: connection,
            operationManager: operationManager,
            identityOperationFactory: identityOperationFactory,
            payoutInfoFactory: payoutInfoFactory,
            logger: Logger.shared
        )

        return createView(for: payoutService, state: state)
    }

    private static func createView(
        for payoutService: PayoutRewardsServiceProtocol,
        state: StakingSharedState
    ) -> StakingRewardPayoutsViewProtocol? {
        guard let chainAsset = state.settings.value else {
            return nil
        }

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let payoutsViewModelFactory = StakingPayoutViewModelFactory(
            chainFormat: chainAsset.chain.chainFormat,
            balanceViewModelFactory: balanceViewModelFactory,
            timeFormatter: TotalTimeFormatter()
        )

        let presenter = StakingRewardPayoutsPresenter(viewModelFactory: payoutsViewModelFactory)
        let view = StakingRewardPayoutsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared,
            countdownTimer: CountdownTimer()
        )

        let operationManager = OperationManagerFacade.sharedManager

        let keyFactory = StorageKeyFactory()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        let eraCountdownOperationFactory = EraCountdownOperationFactory(
            storageRequestFactory: storageRequestFactory
        )

        let interactor = StakingRewardPayoutsInteractor(
            chainAsset: chainAsset,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            payoutService: payoutService,
            eraCountdownOperationFactory: eraCountdownOperationFactory,
            operationManager: operationManager
        )

        let wireframe = StakingRewardPayoutsWireframe(state: state)

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
