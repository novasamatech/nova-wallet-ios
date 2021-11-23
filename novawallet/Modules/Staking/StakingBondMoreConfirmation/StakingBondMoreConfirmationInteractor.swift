import RobinHood
import IrohaCrypto
import BigInt
import SoraKeystore

final class StakingBondMoreConfirmationInteractor: AccountFetching {
    weak var presenter: StakingBondMoreConfirmationOutputProtocol!

    let selectedAccount: ChainAccountResponse
    let chainAsset: ChainAsset
    let accountRepositoryFactory: AccountRepositoryFactoryProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let operationManager: OperationManagerProtocol

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var extrinsicService: ExtrinsicServiceProtocol?
    private var signingWrapper: SigningWrapperProtocol?

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
        operationManager: OperationManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.accountRepositoryFactory = accountRepositoryFactory
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.feeProxy = feeProxy
        self.operationManager = operationManager
    }

    func handleStashMetaAccount(response: MetaChainAccountResponse) {
        extrinsicService = extrinsicServiceFactory.createService(
            accountId: response.chainAccount.accountId,
            chainFormat: response.chainAccount.chainFormat,
            cryptoType: response.chainAccount.cryptoType
        )

        signingWrapper = extrinsicServiceFactory.createSigningWrapper(
            metaId: response.metaId,
            account: response.chainAccount
        )
    }
}

extension StakingBondMoreConfirmationInteractor: StakingBondMoreConfirmationInteractorInputProtocol {
    func setup() {
        if let address = selectedAccount.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        } else {
            presenter.didReceivePriceData(result: .success(nil))
        }

        feeProxy.delegate = self
    }

    func estimateFee(for amount: Decimal) {
        guard let extrinsicService = extrinsicService,
              let amountValue = amount.toSubstrateAmount(
                  precision: chainAsset.assetDisplayInfo.assetPrecision
              ) else {
            presenter.didReceiveFee(result: .failure(CommonError.undefined))
            return
        }

        let bondExtra = callFactory.bondExtra(amount: amountValue)

        let idetifier = bondExtra.callName + amountValue.description

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: idetifier) { builder in
            try builder.adding(call: bondExtra)
        }
    }

    func submit(for amount: Decimal) {
        guard
            let extrinsicService = extrinsicService,
            let signingWrapper = signingWrapper,
            let amountValue = amount.toSubstrateAmount(
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ) else {
            presenter.didSubmitBonding(result: .failure(CommonError.undefined))
            return
        }

        let bondExtra = callFactory.bondExtra(amount: amountValue)

        extrinsicService.submit(
            { builder in
                try builder.adding(call: bondExtra)
            },
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] result in
                self?.presenter.didSubmitBonding(result: result)
            }
        )
    }
}

extension StakingBondMoreConfirmationInteractor: StakingLocalStorageSubscriber,
    StakingLocalSubscriptionHandler, AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            let maybeStashItem = try result.get()
            let maybeStashId = try maybeStashItem.map { try $0.stash.toAccountId() }

            clear(dataProvider: &balanceProvider)
            presenter.didReceiveStashItem(result: result)

            guard let stashAccountId = maybeStashId else {
                presenter.didReceiveAccountInfo(result: .success(nil))
                return
            }

            balanceProvider = subscribeToAccountInfoProvider(
                for: stashAccountId,
                chainId: chainAsset.chain.chainId
            )

            fetchFirstMetaAccountResponse(
                for: stashAccountId,
                accountRequest: chainAsset.chain.accountRequest(),
                repositoryFactory: accountRepositoryFactory,
                operationManager: operationManager
            ) { [weak self] result in
                if case let .success(maybeStash) = result, let stash = maybeStash {
                    self?.handleStashMetaAccount(response: stash)
                }

                switch result {
                case let .success(response):
                    let accountItem = try? response?.chainAccount.toAccountItem()
                    self?.presenter.didReceiveStash(result: .success(accountItem))
                case let .failure(error):
                    self?.presenter.didReceiveStash(result: .failure(error))
                }
            }

        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
            presenter.didReceiveAccountInfo(result: .failure(error))
        }
    }
}

extension StakingBondMoreConfirmationInteractor: PriceLocalStorageSubscriber,
    PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension StakingBondMoreConfirmationInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension StakingBondMoreConfirmationInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
