import Operation_iOS
import NovaCrypto
import BigInt
import Keystore_iOS

final class StakingBondMoreInteractor: AccountFetching {
    weak var presenter: StakingBondMoreInteractorOutputProtocol!

    let selectedAccount: ChainAccountResponse
    let chainAsset: ChainAsset
    let accountRepositoryFactory: AccountRepositoryFactoryProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var extrinsicService: ExtrinsicServiceProtocol?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?

    private lazy var callFactory = SubstrateCallFactory()

    init(
        selectedAccount: ChainAccountResponse,
        chainAsset: ChainAsset,
        accountRepositoryFactory: AccountRepositoryFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManager
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.accountRepositoryFactory = accountRepositoryFactory
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.runtimeProvider = runtimeProvider
        self.feeProxy = feeProxy
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }
}

private extension StakingBondMoreInteractor {
    func handleStashMetaAccount(response: MetaChainAccountResponse) {
        let chain = chainAsset.chain

        extrinsicService = extrinsicServiceFactory.createService(
            account: response.chainAccount,
            chain: chain
        )

        estimateFee()
    }

    func provideIsStakingMigrated() {
        runtimeProvider.fetchCoderFactory(
            runningIn: operationQueue,
            completion: { [weak self] coderFactory in
                let isStakingMigrated = coderFactory.hasBalancesHold(with: Staking.holdId)
                self?.presenter.didReceiveStakingMigratedToHold(result: .success(isStakingMigrated))
            },
            errorClosure: { [weak self] error in
                self?.presenter.didReceiveStakingMigratedToHold(result: .failure(error))
            }
        )
    }
}

extension StakingBondMoreInteractor: StakingBondMoreInteractorInputProtocol {
    func setup() {
        if let address = selectedAccount.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address, chainId: chainAsset.chain.chainId)
        }

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter.didReceivePriceData(result: .success(nil))
        }

        feeProxy.delegate = self

        provideIsStakingMigrated()
    }

    func estimateFee() {
        guard
            let extrinsicService = extrinsicService,
            let amount = StakingConstants.feeEstimation.toSubstrateAmount(
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ) else {
            return
        }

        let bondExtra = callFactory.bondExtra(amount: amount)

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: bondExtra.callName) { builder in
            try builder.adding(call: bondExtra)
        }
    }
}

extension StakingBondMoreInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            guard let stashItem = try result.get() else {
                presenter.didReceiveStashItem(result: .success(nil))
                presenter.didReceiveAccountBalance(result: .success(nil))
                presenter.didReceiveStakingLedger(result: .success(nil))
                return
            }

            clear(streamableProvider: &balanceProvider)
            clear(dataProvider: &ledgerProvider)

            presenter.didReceiveStashItem(result: result)

            let stashAccountId = try stashItem.stash.toAccountId(using: chainAsset.chain.chainFormat)
            let controllerAccountId = try stashItem.controller.toAccountId(using: chainAsset.chain.chainFormat)

            balanceProvider = subscribeToAssetBalanceProvider(
                for: stashAccountId,
                chainId: chainAsset.chain.chainId,
                assetId: chainAsset.asset.assetId
            )

            ledgerProvider = subscribeLedgerInfo(
                for: controllerAccountId,
                chainId: chainAsset.chain.chainId
            )

            fetchFirstMetaAccountResponse(
                for: stashAccountId,
                accountRequest: chainAsset.chain.accountRequest(),
                repositoryFactory: accountRepositoryFactory,
                operationQueue: operationQueue
            ) { [weak self] result in
                if case let .success(maybeStash) = result, let stash = maybeStash {
                    self?.handleStashMetaAccount(response: stash)
                }

                switch result {
                case let .success(response):
                    let account = response?.chainAccount
                    self?.presenter.didReceiveStash(result: .success(account))
                case let .failure(error):
                    self?.presenter.didReceiveStash(result: .failure(error))
                }
            }

        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
            presenter.didReceiveAccountBalance(result: .failure(error))
            presenter.didReceiveStakingLedger(result: .failure(error))
        }
    }

    func handleLedgerInfo(
        result: Result<Staking.Ledger?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        presenter.didReceiveStakingLedger(result: result)
    }
}

extension StakingBondMoreInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension StakingBondMoreInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        presenter.didReceiveAccountBalance(result: result)
    }
}

extension StakingBondMoreInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        presenter.didReceiveFee(result: result)
    }
}

extension StakingBondMoreInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
