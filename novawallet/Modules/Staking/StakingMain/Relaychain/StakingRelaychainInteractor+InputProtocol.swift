import Foundation
import SoraFoundation

extension StakingRelaychainInteractor: StakingRelaychainInteractorInputProtocol {
    private func continueSetup() {
        setupSelectedAccountAndChainAsset()
        setupChainRemoteSubscription()
        setupAccountRemoteSubscription()

        sharedState.eraValidatorService?.setup()
        sharedState.rewardCalculationService?.setup()
        sharedState.blockTimeService?.setup()

        provideNewChain()
        provideSelectedAccount()

        guard
            let chainId = selectedChainAsset?.chain.chainId,
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId),
            let eraValidatorService = sharedState.eraValidatorService,
            let rewardCalculationService = sharedState.rewardCalculationService else {
            return
        }

        provideMaxNominatorsPerValidator(from: runtimeService)

        performPriceSubscription()
        performAccountInfoSubscription()
        performStashControllerSubscription()
        performNominatorLimitsSubscripion()

        provideRewardCalculator(from: rewardCalculationService)
        provideEraStakersInfo(from: eraValidatorService)

        provideNetworkStakingInfo()

        eventCenter.add(observer: self, dispatchIn: .main)

        applicationHandler.delegate = self
    }

    private func createInitialServices() {
        guard let chainAsset = sharedState.settings.value else {
            return
        }

        do {
            let blockTimeService = try stakingServiceFactory.createBlockTimeService(
                for: chainAsset.chain.chainId,
                consensus: sharedState.consensus
            )

            sharedState.replaceBlockTimeService(blockTimeService)

            let eraValidatorService = try stakingServiceFactory.createEraValidatorService(
                for: chainAsset.chain.chainId
            )

            let stakingDurationFactory = try sharedState.createStakingDurationOperationFactory(for: chainAsset.chain)

            let rewardCalculatorService = try stakingServiceFactory.createRewardCalculatorService(
                for: chainAsset.chain.chainId,
                stakingType: StakingType(rawType: chainAsset.asset.staking),
                stakingDurationFactory: stakingDurationFactory,
                assetPrecision: Int16(chainAsset.asset.precision),
                validatorService: eraValidatorService
            )

            sharedState.replaceEraValidatorService(eraValidatorService)
            sharedState.replaceRewardCalculatorService(rewardCalculatorService)
        } catch {
            logger?.error("Couldn't create shared state")
        }
    }

    func setup() {
        createInitialServices()
        continueSetup()
    }

    private func updateAfterSelectedAccountChange() {
        clearAccountRemoteSubscription()
        clear(dataProvider: &balanceProvider)
        clearStashControllerSubscription()

        guard let selectedChain = selectedChainAsset?.chain,
              let selectedMetaAccount = selectedWalletSettings.value,
              let newSelectedAccount = selectedMetaAccount.fetch(for: selectedChain.accountRequest()) else {
            return
        }

        selectedAccount = newSelectedAccount

        setupAccountRemoteSubscription()

        performAccountInfoSubscription()

        provideSelectedAccount()

        performStashControllerSubscription()
    }
}

extension StakingRelaychainInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        updateAfterSelectedAccountChange()
    }

    func processEraStakersInfoChanged(event _: EraStakersInfoChanged) {
        guard
            let eraValidatorService = sharedState.eraValidatorService,
            let rewardCalculationService = sharedState.rewardCalculationService else {
            return
        }

        provideNetworkStakingInfo()
        provideEraStakersInfo(from: eraValidatorService)
        provideRewardCalculator(from: rewardCalculationService)
    }
}

extension StakingRelaychainInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        priceProvider?.refresh()
        totalRewardProvider?.refresh()
        rewardAnalyticsProvider?.refresh()
    }
}
