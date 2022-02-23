import Foundation
import SoraFoundation
import RobinHood

extension StakingMainInteractor: StakingMainInteractorInputProtocol {
    func saveNetworkInfoViewExpansion(isExpanded: Bool) {
        commonSettings.stakingNetworkExpansion = isExpanded
    }

    private func continueSetup() {
        setupSelectedAccountAndChainAsset()
        setupChainRemoteSubscription()
        setupAccountRemoteSubscription()

        sharedState.eraValidatorService?.setup()
        sharedState.rewardCalculationService?.setup()

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

        presenter.networkInfoViewExpansion(isExpanded: commonSettings.stakingNetworkExpansion)
    }

    private func createInitialServices() {
        guard let chainAsset = sharedState.settings.value else {
            return
        }

        do {
            let eraValidatorService = try stakingServiceFactory.createEraValidatorService(
                for: chainAsset.chain.chainId
            )

            let rewardCalculatorService = try stakingServiceFactory.createRewardCalculatorService(
                for: chainAsset.chain.chainId,
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
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.stakingSettings.setup(runningCompletionIn: .main) { result in
                switch result {
                case .success:
                    self?.createInitialServices()
                    self?.continueSetup()
                case let .failure(error):
                    self?.logger?.error("Staking settings setup error: \(error)")
                }
            }
        }
    }

    func save(chainAsset: ChainAsset) {
        guard selectedChainAsset?.chainAssetId != chainAsset.chainAssetId else {
            return
        }

        stakingSettings.save(value: chainAsset, runningCompletionIn: .main) { [weak self] _ in
            self?.updateAfterChainAssetSave()
            self?.updateAfterSelectedAccountChange()
        }
    }

    private func updateAfterChainAssetSave() {
        clearCancellable()
        clear(singleValueProvider: &priceProvider)
        clearNominatorsLimitProviders()

        guard let newSelectedChainAsset = stakingSettings.value else {
            return
        }

        selectedChainAsset.map { clearChainRemoteSubscription(for: $0.chain.chainId) }

        selectedChainAsset = newSelectedChainAsset

        setupChainRemoteSubscription()

        updateSharedState()

        provideNewChain()

        performPriceSubscription()

        performNominatorLimitsSubscripion()

        guard
            let chainId = selectedChainAsset?.chain.chainId,
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId),
            let eraValidatorService = sharedState.eraValidatorService,
            let rewardCalculationService = sharedState.rewardCalculationService else {
            return
        }

        provideEraStakersInfo(from: eraValidatorService)
        provideNetworkStakingInfo()
        provideRewardCalculator(from: rewardCalculationService)
        provideMaxNominatorsPerValidator(from: runtimeService)
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

extension StakingMainInteractor: EventVisitorProtocol {
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

extension StakingMainInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        priceProvider?.refresh()
        totalRewardProvider?.refresh()
        rewardAnalyticsProvider?.refresh()
    }
}
