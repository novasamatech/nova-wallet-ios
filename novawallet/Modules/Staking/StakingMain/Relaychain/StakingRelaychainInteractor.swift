import Foundation
import SoraFoundation
import RobinHood

final class StakingRelaychainInteractor: RuntimeConstantFetching, AnyCancellableCleaning {
    weak var presenter: StakingRelaychainInteractorOutputProtocol?

    var stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol {
        sharedState.stakingLocalSubscriptionFactory
    }

    var stakingAnalyticsLocalSubscriptionFactory: StakingAnalyticsLocalSubscriptionFactoryProtocol {
        sharedState.stakingAnalyticsLocalSubscriptionFactory
    }

    var stakingSettings: StakingAssetSettings { sharedState.settings }

    let selectedWalletSettings: SelectedWalletSettings
    let sharedState: StakingSharedState
    let chainRegistry: ChainRegistryProtocol
    let stakingRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocol
    let stakingAccountUpdatingService: StakingAccountUpdatingServiceProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let stakingServiceFactory: StakingServiceFactoryProtocol
    let accountProviderFactory: AccountProviderFactoryProtocol
    let eventCenter: EventCenterProtocol
    let operationManager: OperationManagerProtocol
    let eraInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol
    let logger: LoggerProtocol?

    var selectedAccount: ChainAccountResponse?
    var selectedChainAsset: ChainAsset?

    private var chainSubscriptionId: UUID?
    private var maxNominatorsPerValidatorCancellable: CancellableCall?
    private var eraStakersInfoCancellable: CancellableCall?
    private var networkInfoCancellable: CancellableCall?
    private var eraCompletionTimeCancellable: CancellableCall?
    private var rewardCalculatorCancellable: CancellableCall?

    var priceProvider: AnySingleValueProvider<PriceData>?
    var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    var stashControllerProvider: StreamableProvider<StashItem>?
    var validatorProvider: AnyDataProvider<DecodedValidator>?
    var nominatorProvider: AnyDataProvider<DecodedNomination>?
    var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    var totalRewardProvider: AnySingleValueProvider<TotalRewardItem>?
    var payeeProvider: AnyDataProvider<DecodedPayee>?
    var controllerAccountProvider: StreamableProvider<MetaAccountModel>?
    var stashAccountProvider: StreamableProvider<MetaAccountModel>?
    var minNominatorBondProvider: AnyDataProvider<DecodedBigUInt>?
    var counterForNominatorsProvider: AnyDataProvider<DecodedU32>?
    var maxNominatorsCountProvider: AnyDataProvider<DecodedU32>?
    var rewardAnalyticsProvider: AnySingleValueProvider<[SubqueryRewardItemData]>?

    init(
        selectedWalletSettings: SelectedWalletSettings,
        sharedState: StakingSharedState,
        chainRegistry: ChainRegistryProtocol,
        stakingRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocol,
        stakingAccountUpdatingService: StakingAccountUpdatingServiceProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingServiceFactory: StakingServiceFactoryProtocol,
        accountProviderFactory: AccountProviderFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationManager: OperationManagerProtocol,
        eraInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.sharedState = sharedState
        self.chainRegistry = chainRegistry
        self.stakingRemoteSubscriptionService = stakingRemoteSubscriptionService
        self.stakingAccountUpdatingService = stakingAccountUpdatingService
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.stakingServiceFactory = stakingServiceFactory
        self.accountProviderFactory = accountProviderFactory
        self.eventCenter = eventCenter
        self.operationManager = operationManager
        self.eraInfoOperationFactory = eraInfoOperationFactory
        self.applicationHandler = applicationHandler
        self.eraCountdownOperationFactory = eraCountdownOperationFactory
        self.logger = logger
    }

    deinit {
        if let selectedChainAsset = selectedChainAsset {
            clearChainRemoteSubscription(for: selectedChainAsset.chain.chainId)
        }

        clearAccountRemoteSubscription()
        clearCancellable()

        sharedState.eraValidatorService?.throttle()
        sharedState.rewardCalculationService?.throttle()
    }

    func clearCancellable() {
        clear(cancellable: &maxNominatorsPerValidatorCancellable)
        clear(cancellable: &eraCompletionTimeCancellable)
        clear(cancellable: &eraStakersInfoCancellable)
        clear(cancellable: &networkInfoCancellable)
        clear(cancellable: &rewardCalculatorCancellable)
    }

    func setupSelectedAccountAndChainAsset() {
        guard
            let wallet = selectedWalletSettings.value,
            let chainAsset = stakingSettings.value,
            let response = wallet.fetch(for: chainAsset.chain.accountRequest()) else {
            return
        }

        selectedAccount = response
        selectedChainAsset = chainAsset
    }

    func clearChainRemoteSubscription(for chainId: ChainModel.Id) {
        if let chainSubscriptionId = chainSubscriptionId {
            stakingRemoteSubscriptionService.detachFromGlobalData(
                for: chainSubscriptionId,
                chainId: chainId,
                queue: nil,
                closure: nil
            )

            self.chainSubscriptionId = nil
        }
    }

    func setupChainRemoteSubscription() {
        guard let chainId = selectedChainAsset?.chain.chainId else {
            return
        }

        chainSubscriptionId = stakingRemoteSubscriptionService.attachToGlobalData(
            for: chainId,
            queue: nil,
            closure: nil
        )
    }

    func clearAccountRemoteSubscription() {
        stakingAccountUpdatingService.clearSubscription()
    }

    func setupAccountRemoteSubscription() {
        guard
            let chainId = selectedChainAsset?.chain.chainId,
            let accountId = selectedAccount?.accountId,
            let chainFormat = selectedChainAsset?.chain.chainFormat else {
            return
        }

        do {
            try stakingAccountUpdatingService.setupSubscription(
                for: accountId,
                chainId: chainId,
                chainFormat: chainFormat
            )
        } catch {
            logger?.error("Could setup staking account subscription")
        }
    }

    func provideSelectedAccount() {
        guard let address = selectedAccount?.toAddress() else {
            return
        }

        presenter?.didReceive(selectedAddress: address)
    }

    func provideMaxNominatorsPerValidator(from runtimeService: RuntimeCodingServiceProtocol) {
        clear(cancellable: &maxNominatorsPerValidatorCancellable)

        maxNominatorsPerValidatorCancellable = fetchConstant(
            for: .maxNominatorRewardedPerValidator,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<UInt32, Error>) in
            if self?.maxNominatorsPerValidatorCancellable != nil {
                self?.maxNominatorsPerValidatorCancellable = nil
                self?.presenter?.didReceiveMaxNominatorsPerValidator(result: result)
            }
        }
    }

    func provideNewChain() {
        guard let chainAsset = selectedChainAsset else {
            return
        }

        presenter?.didReceive(newChainAsset: chainAsset)
    }

    func provideRewardCalculator(from calculatorService: RewardCalculatorServiceProtocol) {
        clear(cancellable: &rewardCalculatorCancellable)

        let operation = calculatorService.fetchCalculatorOperation()

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.rewardCalculatorCancellable === operation else {
                    return
                }

                self?.rewardCalculatorCancellable = nil

                do {
                    let engine = try operation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(calculator: engine)
                } catch {
                    self?.presenter?.didReceive(calculatorError: error)
                }
            }
        }

        rewardCalculatorCancellable = operation

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func provideEraStakersInfo(from eraValidatorService: EraValidatorServiceProtocol) {
        clear(cancellable: &eraStakersInfoCancellable)

        let operation = eraValidatorService.fetchInfoOperation()

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.eraStakersInfoCancellable === operation else {
                    return
                }

                self?.eraStakersInfoCancellable = nil

                do {
                    let info = try operation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(eraStakersInfo: info)
                    self?.fetchEraCompletionTime()
                } catch {
                    self?.presenter?.didReceive(calculatorError: error)
                }
            }
        }

        eraStakersInfoCancellable = operation

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func provideNetworkStakingInfo() {
        clear(cancellable: &networkInfoCancellable)

        guard let chainId = selectedChainAsset?.chain.chainId else {
            return
        }

        guard
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId),
            let eraValidatorService = sharedState.eraValidatorService else {
            presenter?.didReceive(networkStakingInfoError: ChainRegistryError.runtimeMetadaUnavailable)
            return
        }

        let wrapper = eraInfoOperationFactory.networkStakingOperation(
            for: eraValidatorService,
            runtimeService: runtimeService
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.networkInfoCancellable === wrapper else {
                    return
                }

                self?.networkInfoCancellable = nil

                do {
                    let info = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(networkStakingInfo: info)
                } catch {
                    self?.presenter?.didReceive(networkStakingInfoError: error)
                }
            }
        }

        networkInfoCancellable = wrapper

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }

    func fetchEraCompletionTime() {
        clear(cancellable: &eraCompletionTimeCancellable)

        guard let chainId = selectedChainAsset?.chain.chainId else {
            return
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            presenter?.didReceive(eraCountdownResult: .failure(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            presenter?.didReceive(eraCountdownResult: .failure(ChainRegistryError.connectionUnavailable))
            return
        }

        let operationWrapper = eraCountdownOperationFactory.fetchCountdownOperationWrapper(
            for: connection,
            runtimeService: runtimeService
        )

        operationWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.eraCompletionTimeCancellable === operationWrapper else {
                    return
                }

                self?.eraCompletionTimeCancellable = nil

                do {
                    let result = try operationWrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(eraCountdownResult: .success(result))
                } catch {
                    self?.presenter?.didReceive(eraCountdownResult: .failure(error))
                }
            }
        }

        eraCompletionTimeCancellable = operationWrapper

        operationManager.enqueue(operations: operationWrapper.allOperations, in: .transient)
    }
}
