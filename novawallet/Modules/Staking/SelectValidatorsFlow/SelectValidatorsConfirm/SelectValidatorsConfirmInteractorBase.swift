import Foundation
import RobinHood
import BigInt

class SelectValidatorsConfirmInteractorBase: SelectValidatorsConfirmInteractorInputProtocol,
    StakingDurationFetching {
    weak var presenter: SelectValidatorsConfirmInteractorOutputProtocol!

    let balanceAccountAddress: AccountAddress
    let chainAsset: ChainAsset
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let durationOperationFactory: StakingDurationOperationFactoryProtocol
    let bondingAccountSigningFactory: BondingAccountSigningFactoryProtocol
    lazy var operationManager = OperationManager(operationQueue: operationQueue)

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?
    private var minBondProvider: AnyDataProvider<DecodedBigUInt>?
    private var counterForNominatorsProvider: AnyDataProvider<DecodedU32>?
    private var maxNominatorsCountProvider: AnyDataProvider<DecodedU32>?
    private(set) var extrinsicService: ExtrinsicServiceProtocol?
    private(set) var signer: SigningWrapperProtocol?
    private let operationQueue: OperationQueue
    private let extrinsicServiceCallStore = CancellableCallStore()
    private let signServiceCallStore = CancellableCallStore()

    init(
        balanceAccountAddress: AccountAddress,
        chainAsset: ChainAsset,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        durationOperationFactory: StakingDurationOperationFactoryProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol,
        bondingAccountSigningFactory: BondingAccountSigningFactoryProtocol
    ) {
        self.balanceAccountAddress = balanceAccountAddress
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.runtimeService = runtimeService
        self.durationOperationFactory = durationOperationFactory
        self.operationQueue = operationQueue
        self.chainAsset = chainAsset
        self.bondingAccountSigningFactory = bondingAccountSigningFactory
        self.currencyManager = currencyManager
    }

    // MARK: - SelectValidatorsConfirmInteractorInputProtocol

    func setup() {
        createSigningServices()

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter.didReceivePrice(result: .success(nil))
        }

        if let accountId = try? balanceAccountAddress.toAccountId() {
            balanceProvider = subscribeToAssetBalanceProvider(
                for: accountId,
                chainId: chainAsset.chain.chainId,
                assetId: chainAsset.asset.assetId
            )
        }

        minBondProvider = subscribeToMinNominatorBond(for: chainAsset.chain.chainId)

        counterForNominatorsProvider = subscribeToCounterForNominators(for: chainAsset.chain.chainId)

        maxNominatorsCountProvider = subscribeMaxNominatorsCount(for: chainAsset.chain.chainId)

        fetchStakingDuration(
            runtimeCodingService: runtimeService,
            operationFactory: durationOperationFactory,
            operationManager: operationManager
        ) { [weak self] result in
            self?.presenter.didReceiveStakingDuration(result: result)
        }
    }

    func submitNomination() {}

    func estimateFee() {}

    func createSigningServices() {
        createExtrinsicService()
        createSigner()
    }

    func createSigner() {
        let wrapper = bondingAccountSigningFactory.createSigner()
        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: signServiceCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(signer):
                self?.signer = signer
            case let .failure(error):
                self?.presenter.didReceive(createSigningServiceError: error)
            }
        }
    }

    func createExtrinsicService() {
        let wrapper = bondingAccountSigningFactory.createExtrinsicService()
        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: extrinsicServiceCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(service):
                self?.extrinsicService = service
                self?.estimateFee()
            case let .failure(error):
                self?.presenter.didReceive(createSigningServiceError: error)
            }
        }
    }
}

extension SelectValidatorsConfirmInteractorBase: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        presenter.didReceiveMinBond(result: result)
    }

    func handleCounterForNominators(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        presenter.didReceiveCounterForNominators(result: result)
    }

    func handleMaxNominatorsCount(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        presenter.didReceiveMaxNominatorsCount(result: result)
    }
}

extension SelectValidatorsConfirmInteractorBase: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        presenter.didReceiveAccountBalance(result: result)
    }
}

extension SelectValidatorsConfirmInteractorBase: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePrice(result: result)
    }
}

extension SelectValidatorsConfirmInteractorBase: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
