import SoraKeystore
import RobinHood
import IrohaCrypto

final class StakingRewardDestSetupInteractor: AccountFetching {
    weak var presenter: StakingRewardDestSetupInteractorOutputProtocol!

    let selectedAccount: ChainAccountResponse
    let chainAsset: ChainAsset
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let calculatorService: RewardCalculatorServiceProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    let accountRepositoryFactory: AccountRepositoryFactoryProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var payeeProvider: AnyDataProvider<DecodedPayee>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var nominationProvider: AnyDataProvider<DecodedNomination>?

    private var stashItem: StashItem?

    private var extrinsicService: ExtrinsicServiceProtocol?

    private lazy var callFactory = SubstrateCallFactory()
    private lazy var addressFactory = SS58AddressFactory()

    init(
        selectedAccount: ChainAccountResponse,
        chainAsset: ChainAsset,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        calculatorService: RewardCalculatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        accountRepositoryFactory: AccountRepositoryFactoryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.calculatorService = calculatorService
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.accountRepositoryFactory = accountRepositoryFactory
        self.feeProxy = feeProxy
    }

    private func provideRewardCalculator() {
        let operation = calculatorService.fetchCalculatorOperation()

        operation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
                do {
                    let engine = try operation.extractNoCancellableResultData()
                    self?.presenter.didReceiveCalculator(result: .success(engine))
                } catch {
                    self?.presenter.didReceiveCalculator(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(
            operations: [operation],
            in: .transient
        )
    }

    private func handleStashItemAccounts(for stashId: AccountId, controllerId: AccountId) {
        fetchFirstMetaAccountResponse(
            for: controllerId,
            accountRequest: chainAsset.chain.accountRequest(),
            repositoryFactory: accountRepositoryFactory,
            operationManager: operationManager
        ) { [weak self] result in
            switch result {
            case let .success(accountResponse):
                if let accountResponse = accountResponse {
                    self?.extrinsicService = self?.extrinsicServiceFactory.createService(
                        accountId: accountResponse.chainAccount.accountId,
                        chainFormat: accountResponse.chainAccount.chainFormat,
                        cryptoType: accountResponse.chainAccount.cryptoType
                    )

                    self?.estimateFee()
                }

                let maybeAccountItem = try? accountResponse?.chainAccount.toAccountItem()
                self?.presenter.didReceiveController(result: .success(maybeAccountItem))
            case let .failure(error):
                self?.presenter.didReceiveController(result: .failure(error))
            }
        }

        fetchFirstAccount(
            for: stashId,
            accountRequest: chainAsset.chain.accountRequest(),
            repositoryFactory: accountRepositoryFactory,
            operationManager: operationManager
        ) { [weak self] result in
            self?.presenter.didReceiveStash(result: result)
        }
    }
}

extension StakingRewardDestSetupInteractor: StakingRewardDestSetupInteractorInputProtocol {
    func setup() {
        if let address = try? selectedAccount.accountId.toAddress(using: chainAsset.chain.chainFormat) {
            stashItemProvider = subscribeStashItemProvider(for: address)
        } else {
            presenter.didReceiveStashItem(result: .failure(CommonError.undefined))
        }

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        } else {
            presenter.didReceivePriceData(result: .success(nil))
        }

        provideRewardCalculator()

        feeProxy.delegate = self
    }

    func estimateFee() {
        guard let extrinsicService = extrinsicService else {
            presenter.didReceiveFee(result: .failure(CommonError.undefined))
            return
        }

        let setPayeeCall = callFactory.setPayee(for: .account(selectedAccount.accountId))

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: setPayeeCall.callName
        ) { builder in
            try builder.adding(call: setPayeeCall)
        }
    }

    func fetchPayoutAccounts() {
        let repository = accountRepositoryFactory.createMetaAccountRepository(
            for: nil,
            sortDescriptors: [NSSortDescriptor.accountsByOrder]
        )

        fetchAllMetaAccountResponses(
            for: chainAsset.chain.accountRequest(),
            repository: repository,
            operationManager: operationManager
        ) { [weak self] result in
            switch result {
            case let .success(responses):
                let accountItems = responses.compactMap { try? $0.chainAccount.toAccountItem() }
                self?.presenter.didReceiveAccounts(result: .success(accountItems))
            case let .failure(error):
                self?.presenter.didReceiveAccounts(result: .failure(error))
            }
        }
    }
}

extension StakingRewardDestSetupInteractor: StakingLocalStorageSubscriber,
    StakingLocalSubscriptionHandler, AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            clear(dataProvider: &ledgerProvider)
            clear(dataProvider: &payeeProvider)
            clear(dataProvider: &accountInfoProvider)
            clear(dataProvider: &nominationProvider)

            stashItem = try result.get()

            let maybeStashId = try stashItem.map { try $0.stash.toAccountId() }
            let maybeControllerId = try stashItem.map { try $0.controller.toAccountId() }

            presenter.didReceiveStashItem(result: result)

            if let stashId = maybeStashId, let controllerId = maybeControllerId {
                ledgerProvider = subscribeLedgerInfo(
                    for: controllerId,
                    chainId: chainAsset.chain.chainId
                )

                payeeProvider = subscribePayee(
                    for: stashId,
                    chainId: chainAsset.chain.chainId
                )

                nominationProvider = subscribeNomination(
                    for: stashId,
                    chainId: chainAsset.chain.chainId
                )

                accountInfoProvider = subscribeToAccountInfoProvider(
                    for: controllerId,
                    chainId: chainAsset.chain.chainId
                )

                handleStashItemAccounts(for: stashId, controllerId: controllerId)

            } else {
                presenter.didReceiveStakingLedger(result: .success(nil))
                presenter.didReceiveAccountInfo(result: .success(nil))
                presenter.didReceiveRewardDestinationAccount(result: .success(nil))
                presenter.didReceiveNomination(result: .success(nil))
                presenter.didReceiveController(result: .success(nil))
            }

        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
            presenter.didReceiveController(result: .failure(error))
            presenter.didReceiveStakingLedger(result: .failure(error))
            presenter.didReceiveAccountInfo(result: .failure(error))
            presenter.didReceiveRewardDestinationAccount(result: .failure(error))
            presenter.didReceiveNomination(result: .failure(error))
        }
    }

    func handleLedgerInfo(
        result: Result<StakingLedger?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        presenter.didReceiveStakingLedger(result: result)
    }

    func handleNomination(
        result: Result<Nomination?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        presenter.didReceiveNomination(result: result)
    }

    func handlePayee(
        result: Result<RewardDestinationArg?, Error>,
        accountId: AccountId,
        chainId _: ChainModel.Id
    ) {
        do {
            guard let payee = try result.get(), let stashItem = stashItem else {
                presenter.didReceiveRewardDestinationAccount(result: .failure(CommonError.undefined))
                return
            }

            let rewardDestination = try RewardDestination(
                payee: payee,
                stashItem: stashItem,
                chainFormat: chainAsset.chain.chainFormat
            )

            switch rewardDestination {
            case .restake:
                presenter.didReceiveRewardDestinationAccount(result: .success(.restake))
            case let .payout(account):
                let accountId = try account.toAccountId()
                fetchFirstAccount(
                    for: accountId,
                    accountRequest: chainAsset.chain.accountRequest(),
                    repositoryFactory: accountRepositoryFactory,
                    operationManager: operationManager
                ) { [weak self] result in
                    switch result {
                    case let .success(accountItem):
                        if let accountItem = accountItem {
                            self?.presenter.didReceiveRewardDestinationAccount(
                                result: .success(.payout(account: accountItem))
                            )
                        } else {
                            self?.presenter.didReceiveRewardDestinationAddress(
                                result: .success(.payout(account: account))
                            )
                        }
                    case let .failure(error):
                        self?.presenter.didReceiveRewardDestinationAccount(result: .failure(error))
                    }
                }
            }
        } catch {
            presenter.didReceiveRewardDestinationAccount(result: .failure(error))
        }
    }
}

extension StakingRewardDestSetupInteractor: WalletLocalStorageSubscriber,
    WalletLocalSubscriptionHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension StakingRewardDestSetupInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension StakingRewardDestSetupInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
