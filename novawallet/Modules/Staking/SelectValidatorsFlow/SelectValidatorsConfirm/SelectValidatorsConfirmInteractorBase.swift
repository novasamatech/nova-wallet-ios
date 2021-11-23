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
    let extrinsicService: ExtrinsicServiceProtocol
    let durationOperationFactory: StakingDurationOperationFactoryProtocol
    let signer: SigningWrapperProtocol
    let operationManager: OperationManagerProtocol

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var minBondProvider: AnyDataProvider<DecodedBigUInt>?
    private var counterForNominatorsProvider: AnyDataProvider<DecodedU32>?
    private var maxNominatorsCountProvider: AnyDataProvider<DecodedU32>?

    init(
        balanceAccountAddress: AccountAddress,
        chainAsset: ChainAsset,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        durationOperationFactory: StakingDurationOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        signer: SigningWrapperProtocol
    ) {
        self.balanceAccountAddress = balanceAccountAddress
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicService = extrinsicService
        self.runtimeService = runtimeService
        self.durationOperationFactory = durationOperationFactory
        self.operationManager = operationManager
        self.signer = signer
        self.chainAsset = chainAsset
    }

    // MARK: - SelectValidatorsConfirmInteractorInputProtocol

    func setup() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        } else {
            presenter.didReceivePrice(result: .success(nil))
        }

        if let accountId = try? balanceAccountAddress.toAccountId() {
            balanceProvider = subscribeToAccountInfoProvider(for: accountId, chainId: chainAsset.chain.chainId)
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
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension SelectValidatorsConfirmInteractorBase: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePrice(result: result)
    }
}
