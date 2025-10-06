import Foundation
import Foundation_iOS
import Operation_iOS
import SubstrateSdk

final class StakingRelaychainInteractor: RuntimeConstantFetching, AnyCancellableCleaning {
    weak var presenter: StakingRelaychainInteractorOutputProtocol?

    var stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol {
        sharedState.localSubscriptionFactory
    }

    var stakingRewardsLocalSubscriptionFactory: StakingRewardsLocalSubscriptionFactoryProtocol {
        sharedState.stakingRewardsLocalSubscriptionFactory
    }

    var proxyListLocalSubscriptionFactory: ProxyListLocalSubscriptionFactoryProtocol {
        sharedState.proxyLocalSubscriptionFactory
    }

    var stakingOption: Multistaking.ChainAssetOption { sharedState.stakingOption }

    let chainRegistry: ChainRegistryProtocol

    let selectedWalletSettings: SelectedWalletSettings
    let sharedState: RelaychainStakingSharedStateProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let accountProviderFactory: AccountProviderFactoryProtocol
    let eventCenter: EventCenterProtocol
    let operationManager: OperationManagerProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let networkInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol
    let eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol
    let logger: LoggerProtocol?

    var selectedAccount: ChainAccountResponse?
    var selectedChainAsset: ChainAsset?

    private var maxNominatorsPerValidatorCancellable: CancellableCall?
    private var eraStakersInfoCancellable: CancellableCall?
    private var networkInfoCancellable: CancellableCall?
    private var eraCompletionTimeCancellable: CancellableCall?
    private var rewardCalculatorCancellable: CancellableCall?

    var stashItem: StashItem?
    var priceProvider: StreamableProvider<PriceData>?
    var balanceProvider: StreamableProvider<AssetBalance>?
    var stashControllerProvider: StreamableProvider<StashItem>?
    var validatorProvider: AnyDataProvider<DecodedValidator>?
    var nominatorProvider: AnyDataProvider<DecodedNomination>?
    var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    var bagListNodeProvider: AnyDataProvider<DecodedBagListNode>?
    var totalRewardProvider: AnySingleValueProvider<TotalRewardItem>?
    var payeeProvider: AnyDataProvider<DecodedPayee>?
    var controllerAccountProvider: StreamableProvider<MetaAccountModel>?
    var stashAccountProvider: StreamableProvider<MetaAccountModel>?
    var minNominatorBondProvider: AnyDataProvider<DecodedBigUInt>?
    var counterForNominatorsProvider: AnyDataProvider<DecodedU32>?
    var maxNominatorsCountProvider: AnyDataProvider<DecodedU32>?
    var bagListSizeProvider: AnyDataProvider<DecodedU32>?
    var totalIssuanceProvider: AnyDataProvider<DecodedBigUInt>?
    var totalRewardInterval: (startTimestamp: Int64?, endTimestamp: Int64?)?
    var proxyProvider: AnyDataProvider<DecodedProxyDefinition>?

    init(
        selectedWalletSettings: SelectedWalletSettings,
        sharedState: RelaychainStakingSharedStateProtocol,
        chainRegistry: ChainRegistryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        accountProviderFactory: AccountProviderFactoryProtocol,
        networkInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol,
        eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationManager: OperationManagerProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        currencyManager: CurrencyManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.chainRegistry = chainRegistry
        self.sharedState = sharedState
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.networkInfoOperationFactory = networkInfoOperationFactory
        self.eraCountdownOperationFactory = eraCountdownOperationFactory
        self.accountProviderFactory = accountProviderFactory
        self.eventCenter = eventCenter
        self.operationManager = operationManager
        self.applicationHandler = applicationHandler
        self.logger = logger
        self.currencyManager = currencyManager
    }

    deinit {
        sharedState.throttle()

        clearCancellable()
    }

    func clearCancellable() {
        clear(cancellable: &maxNominatorsPerValidatorCancellable)
        clear(cancellable: &eraCompletionTimeCancellable)
        clear(cancellable: &eraStakersInfoCancellable)
        clear(cancellable: &networkInfoCancellable)
        clear(cancellable: &rewardCalculatorCancellable)
    }

    func setupSelectedAccountAndChainAsset() {
        guard let wallet = selectedWalletSettings.value else {
            return
        }

        let chainAsset = stakingOption.chainAsset

        selectedAccount = wallet.fetch(for: chainAsset.chain.accountRequest())
        selectedChainAsset = chainAsset
    }

    func provideSelectedAccount() {
        guard let address = selectedAccount?.toAddress() else {
            return
        }

        presenter?.didReceive(selectedAddress: address)
    }

    func provideMaxNominatorsPerValidator(from runtimeService: RuntimeCodingServiceProtocol) {
        clear(cancellable: &maxNominatorsPerValidatorCancellable)

        let wrapper: CompoundOperationWrapper<UInt32?> = PrimitiveConstantOperation.wrapperNilIfMissing(
            for: Staking.maxNominatorRewardedPerValidatorPath,
            runtimeService: runtimeService
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                if self?.maxNominatorsPerValidatorCancellable != nil {
                    self?.maxNominatorsPerValidatorCancellable = nil

                    do {
                        let value = try wrapper.targetOperation.extractNoCancellableResultData()
                        self?.presenter?.didReceiveMaxNominatorsPerValidator(result: .success(value))
                    } catch {
                        self?.presenter?.didReceiveMaxNominatorsPerValidator(result: .failure(error))
                    }
                }
            }
        }

        maxNominatorsPerValidatorCancellable = wrapper

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
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

        guard let chain = selectedChainAsset?.chain else {
            return
        }

        let eraValidatorService = sharedState.eraValidatorService

        let chainId = chain.chainId

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            presenter?.didReceive(networkStakingInfoError: ChainRegistryError.runtimeMetadaUnavailable)
            return
        }

        let wrapper = networkInfoOperationFactory.networkStakingOperation(
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

        let operationWrapper = eraCountdownOperationFactory.fetchCountdownOperationWrapper()

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
