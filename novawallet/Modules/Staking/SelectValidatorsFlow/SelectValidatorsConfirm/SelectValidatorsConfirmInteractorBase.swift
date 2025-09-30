import Foundation
import Operation_iOS
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

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?
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
        signer: SigningWrapperProtocol,
        currencyManager: CurrencyManagerProtocol
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
        self.currencyManager = currencyManager
    }

    // MARK: - SelectValidatorsConfirmInteractorInputProtocol

    func setup() {
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
