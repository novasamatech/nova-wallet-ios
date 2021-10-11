import SoraKeystore
import RobinHood
import BigInt
import FearlessUtils

final class StakingUnbondSetupInteractor: RuntimeConstantFetching, AccountFetching,
    StakingDurationFetching {
    weak var presenter: StakingUnbondSetupInteractorOutputProtocol!

    let selectedAccount: ChainAccountResponse
    let chainAsset: ChainAsset
    let chainRegistry: ChainRegistryProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let stakingDurationOperationFactory: StakingDurationOperationFactoryProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let accountRepositoryFactory: AccountRepositoryFactoryProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let operationManager: OperationManagerProtocol

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?

    private var extrinisicService: ExtrinsicServiceProtocol?

    private lazy var callFactory = SubstrateCallFactory()

    init(
        selectedAccount: ChainAccountResponse,
        chainAsset: ChainAsset,
        chainRegistry: ChainRegistryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingDurationOperationFactory: StakingDurationOperationFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        accountRepositoryFactory: AccountRepositoryFactoryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.chainRegistry = chainRegistry
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.stakingDurationOperationFactory = stakingDurationOperationFactory
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.accountRepositoryFactory = accountRepositoryFactory
        self.feeProxy = feeProxy
        self.operationManager = operationManager
    }

    func handleControllerMetaAccount(response: MetaChainAccountResponse) {
        extrinisicService = extrinsicServiceFactory.createService(
            accountId: response.chainAccount.accountId,
            chainFormat: response.chainAccount.chainFormat,
            cryptoType: response.chainAccount.cryptoType
        )

        estimateFee()
    }
}

extension StakingUnbondSetupInteractor: StakingUnbondSetupInteractorInputProtocol {
    func setup() {
        if let address = selectedAccount.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        } else {
            presenter.didReceiveStashItem(result: .failure(ChainAccountFetchingError.accountNotExists))
        }

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        } else {
            presenter.didReceivePriceData(result: .success(nil))
        }

        if let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) {
            fetchStakingDuration(
                runtimeCodingService: runtimeService,
                operationFactory: stakingDurationOperationFactory,
                operationManager: operationManager
            ) { [weak self] result in
                self?.presenter.didReceiveStakingDuration(result: result)
            }

            fetchConstant(
                for: .lockUpPeriod,
                runtimeCodingService: runtimeService,
                operationManager: operationManager
            ) { [weak self] (result: Result<UInt32, Error>) in
                self?.presenter.didReceiveBondingDuration(result: result)
            }

            fetchConstant(
                for: .existentialDeposit,
                runtimeCodingService: runtimeService,
                operationManager: operationManager
            ) { [weak self] (result: Result<BigUInt, Error>) in
                self?.presenter.didReceiveExistentialDeposit(result: result)
            }
        } else {
            let error = ChainRegistryError.runtimeMetadaUnavailable
            presenter.didReceiveBondingDuration(result: .failure(error))
            presenter.didReceiveExistentialDeposit(result: .failure(error))
            presenter.didReceiveStakingDuration(result: .failure(error))
        }

        feeProxy.delegate = self
    }

    func estimateFee() {
        guard let extrinsicService = extrinisicService,
              let amount = StakingConstants.maxAmount.toSubstrateAmount(
                  precision: chainAsset.assetDisplayInfo.assetPrecision
              ) else {
            return
        }

        let unbondCall = callFactory.unbond(amount: amount)
        let setPayeeCall = callFactory.setPayee(for: .stash)
        let chillCall = callFactory.chill()

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: unbondCall.callName) { builder in
            try builder.adding(call: chillCall).adding(call: unbondCall).adding(call: setPayeeCall)
        }
    }
}

extension StakingUnbondSetupInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            clear(dataProvider: &accountInfoProvider)
            clear(dataProvider: &ledgerProvider)

            let maybeStashItem = try result.get()
            let maybeControllerId = try maybeStashItem.map { try $0.controller.toAccountId() }

            presenter.didReceiveStashItem(result: result)

            guard let controllerId = maybeControllerId else {
                presenter.didReceiveStakingLedger(result: .success(nil))
                presenter.didReceiveAccountInfo(result: .success(nil))
                return
            }

            ledgerProvider = subscribeLedgerInfo(
                for: controllerId,
                chainId: chainAsset.chain.chainId
            )

            accountInfoProvider = subscribeToAccountInfoProvider(
                for: controllerId,
                chainId: chainAsset.chain.chainId
            )

            fetchFirstMetaAccountResponse(
                for: controllerId,
                accountRequest: chainAsset.chain.accountRequest(),
                repositoryFactory: accountRepositoryFactory,
                operationManager: operationManager
            ) { [weak self] result in

                if case let .success(maybeController) = result, let controller = maybeController {
                    self?.handleControllerMetaAccount(response: controller)
                }

                switch result {
                case let .success(response):
                    let accountItem = try? response?.chainAccount.toAccountItem()
                    self?.presenter.didReceiveController(result: .success(accountItem))
                case let .failure(error):
                    self?.presenter.didReceiveController(result: .failure(error))
                }
            }

        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
            presenter.didReceiveAccountInfo(result: .failure(error))
            presenter.didReceiveStakingLedger(result: .failure(error))
        }
    }

    func handleLedgerInfo(
        result: Result<StakingLedger?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        presenter.didReceiveStakingLedger(result: result)
    }
}

extension StakingUnbondSetupInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension StakingUnbondSetupInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension StakingUnbondSetupInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
