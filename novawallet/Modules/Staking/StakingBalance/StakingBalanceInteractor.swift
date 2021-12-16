import RobinHood
import IrohaCrypto

final class StakingBalanceInteractor: AccountFetching {
    weak var presenter: StakingBalanceInteractorOutputProtocol!

    let chainAsset: ChainAsset
    let selectedAccount: ChainAccountResponse
    let chainRegistry: ChainRegistryProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol
    let accountRepositoryFactory: AccountRepositoryFactoryProtocol
    let operationManager: OperationManagerProtocol

    private var activeEraProvider: AnyDataProvider<DecodedActiveEra>?
    private var stashControllerProvider: StreamableProvider<StashItem>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        chainRegistry: ChainRegistryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol,
        accountRepositoryFactory: AccountRepositoryFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.chainRegistry = chainRegistry
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.eraCountdownOperationFactory = eraCountdownOperationFactory
        self.accountRepositoryFactory = accountRepositoryFactory
        self.operationManager = operationManager
    }

    func fetchAccounts(for stashItem: StashItem) {
        let accountRequest = chainAsset.chain.accountRequest()

        do {
            let stashAccountId = try stashItem.stash.toAccountId()

            fetchFirstAccount(
                for: stashAccountId,
                accountRequest: accountRequest,
                repositoryFactory: accountRepositoryFactory,
                operationManager: operationManager
            ) { [weak self] result in
                self?.presenter.didReceive(stashResult: result)
            }
        } catch {
            presenter.didReceive(stashResult: .failure(error))
        }

        do {
            let controllerAccountId = try stashItem.controller.toAccountId()

            fetchFirstAccount(
                for: controllerAccountId,
                accountRequest: accountRequest,
                repositoryFactory: accountRepositoryFactory,
                operationManager: operationManager
            ) { [weak self] result in
                self?.presenter.didReceive(controllerResult: result)
            }
        } catch {
            presenter.didReceive(stashResult: .failure(error))
        }
    }

    func fetchEraCompletionTime() {
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            presenter.didReceive(eraCountdownResult: .failure(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

        guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            presenter.didReceive(eraCountdownResult: .failure(ChainRegistryError.connectionUnavailable))
            return
        }

        let operationWrapper = eraCountdownOperationFactory.fetchCountdownOperationWrapper(
            for: connection,
            runtimeService: runtimeService
        )

        operationWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let result = try operationWrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter.didReceive(eraCountdownResult: .success(result))
                } catch {
                    self?.presenter.didReceive(eraCountdownResult: .failure(error))
                }
            }
        }
        operationManager.enqueue(operations: operationWrapper.allOperations, in: .transient)
    }

    func handle(stashItem: StashItem?) {
        clear(dataProvider: &ledgerProvider)

        if let stashItem = stashItem {
            do {
                let controllerId = try stashItem.controller.toAccountId()
                ledgerProvider = subscribeLedgerInfo(for: controllerId, chainId: chainAsset.chain.chainId)
            } catch {
                presenter.didReceive(ledgerResult: .failure(error))
            }

            fetchAccounts(for: stashItem)
        }

        presenter?.didReceive(stashItemResult: .success(stashItem))
    }
}

extension StakingBalanceInteractor: StakingBalanceInteractorInputProtocol {
    func setup() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        } else {
            presenter.didReceive(priceResult: .success(nil))
        }

        activeEraProvider = subscribeActiveEra(for: chainAsset.chain.chainId)

        if let address = selectedAccount.toAddress() {
            stashControllerProvider = subscribeStashItemProvider(for: address)
        } else {
            presenter.didReceive(stashItemResult: .failure(ChainAccountFetchingError.accountNotExists))
        }

        fetchEraCompletionTime()
    }
}

extension StakingBalanceInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(eraInfo):
            if let eraIndex = eraInfo?.index {
                presenter.didReceive(activeEraResult: .success(eraIndex))
                fetchEraCompletionTime()
            }
        case let .failure(error):
            presenter.didReceive(activeEraResult: .failure(error))
        }
    }

    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        switch result {
        case let .success(stashItem):
            handle(stashItem: stashItem)
        case let .failure(error):
            presenter.didReceive(stashItemResult: .failure(error))
        }
    }

    func handleLedgerInfo(
        result: Result<StakingLedger?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(ledger):
            if let ledger = ledger {
                presenter.didReceive(ledgerResult: .success(ledger))
            }
        case let .failure(error):
            presenter.didReceive(ledgerResult: .failure(error))
        }
    }
}

extension StakingBalanceInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceive(priceResult: result)
    }
}
