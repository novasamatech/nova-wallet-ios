import Foundation
import Keystore_iOS
import Foundation_iOS
import SubstrateSdk
import NovaCrypto

final class StakingRewardPayoutsViewFactory {
    static func createViewForNominator(
        for state: RelaychainStakingSharedStateProtocol,
        stashAddress: AccountAddress
    ) -> StakingRewardPayoutsViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard let rewardsUrls = chainAsset.chain.externalApis?.stakingRewards()?.map(\.url) else {
            return nil
        }

        let validatorsResolutionFactory = PayoutValidatorsForNominatorFactory(
            urls: rewardsUrls
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
        for state: RelaychainStakingSharedStateProtocol,
        stashAddress: AccountAddress
    ) -> StakingRewardPayoutsViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

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
        for state: RelaychainStakingSharedStateProtocol,
        stashAddress: AccountAddress,
        validatorsResolutionFactory: PayoutValidatorsFactoryProtocol,
        payoutInfoFactory: PayoutInfoFactoryProtocol
    ) -> StakingRewardPayoutsViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let identityOperationFactory = IdentityOperationFactory(requestFactory: storageRequestFactory)
        let identityProxyFactory = IdentityProxyFactory(
            originChain: chainAsset.chain,
            chainRegistry: chainRegistry,
            identityOperationFactory: identityOperationFactory
        )

        let exposureFacade = StakingValidatorExposureFacade(
            operationQueue: operationQueue,
            requestFactory: storageRequestFactory
        )

        let unclaimedRewardsFacade = StakingUnclaimedRewardsFacade(
            requestFactory: storageRequestFactory,
            operationQueue: operationQueue
        )

        let payoutService = PayoutRewardsService(
            selectedAccountAddress: stashAddress,
            chainFormat: chainAsset.chain.chainFormat,
            validatorsResolutionFactory: validatorsResolutionFactory,
            erasStakersPagedSearchFactory: ExposurePagedEraOperationFactory(operationQueue: operationQueue),
            exposureFactoryFacade: exposureFacade,
            unclaimedRewardsFacade: unclaimedRewardsFacade,
            runtimeCodingService: runtimeService,
            storageRequestFactory: storageRequestFactory,
            engine: connection,
            operationManager: operationManager,
            identityProxyFactory: identityProxyFactory,
            payoutInfoFactory: payoutInfoFactory,
            logger: Logger.shared
        )

        return createView(for: payoutService, state: state)
    }

    private static func createView(
        for payoutService: PayoutRewardsServiceProtocol,
        state: RelaychainStakingSharedStateProtocol
    ) -> StakingRewardPayoutsViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let eraCountdownOperationFactory = state.createEraCountdownOperationFactory(
            for: OperationManagerFacade.sharedDefaultQueue
        )

        let assetInfo = chainAsset.assetDisplayInfo
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let timeleftViewModelFactory = PayoutTimeViewModelFactory(timeFormatter: TotalTimeFormatter())
        let payoutsViewModelFactory = StakingPayoutViewModelFactory(
            chainFormat: chainAsset.chain.chainFormat,
            balanceViewModelFactory: balanceViewModelFactory,
            timeViewModelFactory: timeleftViewModelFactory
        )

        let presenter = StakingRewardPayoutsPresenter(viewModelFactory: payoutsViewModelFactory)
        let view = StakingRewardPayoutsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared,
            countdownTimer: CountdownTimer()
        )

        let interactor = StakingRewardPayoutsInteractor(
            chainAsset: chainAsset,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            stakingLocalSubscriptionFactory: state.localSubscriptionFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            payoutService: payoutService,
            eraCountdownOperationFactory: eraCountdownOperationFactory,
            operationManager: operationManager,
            currencyManager: currencyManager
        )

        let wireframe = StakingRewardPayoutsWireframe(state: state)

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
