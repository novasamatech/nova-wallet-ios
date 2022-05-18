import Foundation
import RobinHood
import SoraFoundation

final class StakingParachainInteractor: AnyProviderAutoCleaning, AnyCancellableCleaning {
    weak var presenter: StakingParachainInteractorOutputProtocol?

    var stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol {
        sharedState.stakingLocalSubscriptionFactory
    }

    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol {
        sharedState.generalLocalSubscriptionFactory
    }

    let selectedWalletSettings: SelectedWalletSettings
    let sharedState: ParachainStakingSharedState
    let chainRegistry: ChainRegistryProtocol
    let stakingAssetSubscriptionService: StakingRemoteSubscriptionServiceProtocol
    let stakingAccountSubscriptionService: ParachainStakingAccountSubscriptionServiceProtocol
    let scheduledRequestsFactory: ParaStkScheduledRequestsQueryFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let stakingServiceFactory: ParachainStakingServiceFactoryProtocol
    let networkInfoFactory: ParaStkNetworkInfoOperationFactoryProtocol
    let durationOperationFactory: ParaStkDurationOperationFactoryProtocol
    let operationQueue: OperationQueue
    let eventCenter: EventCenterProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let logger: LoggerProtocol?

    var chainSubscriptionId: UUID?
    var accountSubscriptionId: UUID?
    var collatorsInfoCancellable: CancellableCall?
    var rewardCalculatorCancellable: CancellableCall?
    var networkInfoCancellable: CancellableCall?
    var scheduledRequestsCancellable: CancellableCall?
    var durationCancellable: CancellableCall?

    var priceProvider: AnySingleValueProvider<PriceData>?
    var balanceProvider: StreamableProvider<AssetBalance>?
    var delegatorProvider: AnyDataProvider<ParachainStaking.DecodedDelegator>?
    var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?
    var roundInfoProvider: AnyDataProvider<ParachainStaking.DecodedRoundInfo>?
    var totalRewardProvider: AnySingleValueProvider<TotalRewardItem>?

    var selectedAccount: MetaChainAccountResponse?
    var selectedChainAsset: ChainAsset?

    init(
        selectedWalletSettings: SelectedWalletSettings,
        sharedState: ParachainStakingSharedState,
        chainRegistry: ChainRegistryProtocol,
        stakingAssetSubscriptionService: StakingRemoteSubscriptionServiceProtocol,
        stakingAccountSubscriptionService: ParachainStakingAccountSubscriptionServiceProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingServiceFactory: ParachainStakingServiceFactoryProtocol,
        networkInfoFactory: ParaStkNetworkInfoOperationFactoryProtocol,
        durationOperationFactory: ParaStkDurationOperationFactoryProtocol,
        scheduledRequestsFactory: ParaStkScheduledRequestsQueryFactoryProtocol,
        eventCenter: EventCenterProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.sharedState = sharedState
        self.chainRegistry = chainRegistry
        self.stakingAssetSubscriptionService = stakingAssetSubscriptionService
        self.stakingAccountSubscriptionService = stakingAccountSubscriptionService
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.stakingServiceFactory = stakingServiceFactory
        self.networkInfoFactory = networkInfoFactory
        self.durationOperationFactory = durationOperationFactory
        self.scheduledRequestsFactory = scheduledRequestsFactory
        self.eventCenter = eventCenter
        self.applicationHandler = applicationHandler
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        if let selectedChainAsset = selectedChainAsset {
            clearChainRemoteSubscription(for: selectedChainAsset.chain.chainId)
        }

        clearAccountRemoteSubscription()
        clearCancellable()

        sharedState.collatorService?.throttle()
        sharedState.rewardCalculationService?.throttle()
        sharedState.blockTimeService?.throttle()
    }

    func clearCancellable() {
        clear(cancellable: &collatorsInfoCancellable)
        clear(cancellable: &rewardCalculatorCancellable)
        clear(cancellable: &networkInfoCancellable)
        clear(cancellable: &scheduledRequestsCancellable)
        clear(cancellable: &durationCancellable)
    }

    func setupSelectedAccountAndChainAsset() {
        guard
            let wallet = selectedWalletSettings.value,
            let chainAsset = sharedState.settings.value,
            let response = wallet.fetchMetaChainAccount(
                for: chainAsset.chain.accountRequest()
            ) else {
            return
        }

        selectedAccount = response
        selectedChainAsset = chainAsset
    }

    func createInitialServices() {
        guard let chainAsset = sharedState.settings.value else {
            return
        }

        do {
            let chainId = chainAsset.chain.chainId
            let collatorsService = try stakingServiceFactory.createSelectedCollatorsService(
                for: chainId
            )

            let rewardCalculatorService = try stakingServiceFactory.createRewardCalculatorService(
                for: chainId,
                assetPrecision: Int16(chainAsset.asset.precision),
                collatorService: collatorsService
            )

            let blockTimeService = try stakingServiceFactory.createBlockTimeService(
                for: chainId
            )

            sharedState.replaceCollatorService(collatorsService)
            sharedState.replaceRewardCalculatorService(rewardCalculatorService)
            sharedState.replaceBlockTimeService(blockTimeService)
        } catch {
            logger?.error("Couldn't create shared state")
            presenter?.didReceiveError(error)
        }
    }

    func continueSetup() {
        setupSelectedAccountAndChainAsset()
        setupChainRemoteSubscription()
        setupAccountRemoteSubscription()

        sharedState.collatorService?.setup()
        sharedState.rewardCalculationService?.setup()
        sharedState.blockTimeService?.setup()

        provideSelectedChainAsset()
        provideSelectedAccount()

        guard
            let collatorService = sharedState.collatorService,
            let rewardCalculationService = sharedState.rewardCalculationService,
            let blockTimeService = sharedState.blockTimeService else {
            return
        }

        performBlockNumberSubscription()
        performRoundInfoSubscription()
        performPriceSubscription()
        performAssetBalanceSubscription()
        performDelegatorSubscription()
        performTotalRewardSubscription()

        provideRewardCalculator(from: rewardCalculationService)
        provideSelectedCollatorsInfo(from: collatorService)
        provideNetworkInfo(for: collatorService, rewardService: rewardCalculationService)
        provideDurationInfo(for: blockTimeService)

        eventCenter.add(observer: self, dispatchIn: .main)

        applicationHandler.delegate = self
    }

    func updateAfterSelectedAccountChange() {
        clearAccountRemoteSubscription()
        clear(streamableProvider: &balanceProvider)
        clear(dataProvider: &delegatorProvider)
        clear(singleValueProvider: &totalRewardProvider)

        guard let selectedChain = selectedChainAsset?.chain,
              let selectedMetaAccount = selectedWalletSettings.value else {
            return
        }

        selectedAccount = selectedMetaAccount.fetchMetaChainAccount(
            for: selectedChain.accountRequest()
        )

        presenter?.didReceiveAccount(selectedAccount)

        setupAccountRemoteSubscription()

        performAssetBalanceSubscription()
        performDelegatorSubscription()
        performTotalRewardSubscription()
    }

    func provideSelectedChainAsset() {
        guard let chainAsset = selectedChainAsset else {
            return
        }

        presenter?.didReceiveChainAsset(chainAsset)
    }

    func provideSelectedAccount() {
        presenter?.didReceiveAccount(selectedAccount)
    }

    func provideRewardCalculator(
        from calculatorService: ParaStakingRewardCalculatorServiceProtocol
    ) {
        clear(cancellable: &rewardCalculatorCancellable)

        let operation = calculatorService.fetchCalculatorOperation()

        operation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
                guard self?.rewardCalculatorCancellable === operation else {
                    return
                }

                self?.rewardCalculatorCancellable = nil

                do {
                    let engine = try operation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveRewardCalculator(engine)
                } catch {
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        rewardCalculatorCancellable = operation

        operationQueue.addOperation(operation)
    }

    func provideSelectedCollatorsInfo(
        from collatorsService: ParachainStakingCollatorServiceProtocol
    ) {
        clear(cancellable: &collatorsInfoCancellable)

        let operation = collatorsService.fetchInfoOperation()

        operation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
                guard self?.collatorsInfoCancellable === operation else {
                    return
                }

                self?.collatorsInfoCancellable = nil

                do {
                    let info = try operation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveSelectedCollators(info)
                } catch {
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        collatorsInfoCancellable = operation

        operationQueue.addOperation(operation)
    }

    func provideNetworkInfo(
        for collatorService: ParachainStakingCollatorServiceProtocol,
        rewardService: ParaStakingRewardCalculatorServiceProtocol
    ) {
        clear(cancellable: &networkInfoCancellable)

        guard let chainId = selectedChainAsset?.chain.chainId else {
            presenter?.didReceiveError(PersistentValueSettingsError.missingValue)
            return
        }

        guard
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            presenter?.didReceiveError(ChainRegistryError.runtimeMetadaUnavailable)
            return
        }

        let wrapper = networkInfoFactory.networkStakingOperation(
            for: collatorService,
            rewardCalculatorService: rewardService,
            runtimeService: runtimeService
        )

        wrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
                guard self?.networkInfoCancellable === wrapper else {
                    return
                }

                self?.networkInfoCancellable = nil

                do {
                    let info = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveNetworkInfo(info)
                } catch {
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        networkInfoCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    func provideDurationInfo(for blockTimeService: BlockTimeEstimationServiceProtocol) {
        clear(cancellable: &durationCancellable)

        guard let chainId = selectedChainAsset?.chain.chainId else {
            presenter?.didReceiveError(PersistentValueSettingsError.missingValue)
            return
        }

        guard
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            presenter?.didReceiveError(ChainRegistryError.runtimeMetadaUnavailable)
            return
        }

        let wrapper = durationOperationFactory.createDurationOperation(
            from: runtimeService,
            blockTimeEstimationService: blockTimeService
        )

        wrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
                guard self?.durationCancellable === wrapper else {
                    return
                }

                self?.durationCancellable = nil

                do {
                    let info = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveStakingDuration(info)
                } catch {
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        durationCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}
