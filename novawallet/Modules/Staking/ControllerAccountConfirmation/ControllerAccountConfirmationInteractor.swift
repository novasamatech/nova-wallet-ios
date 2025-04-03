import UIKit
import Operation_iOS
import NovaCrypto
import SubstrateSdk

final class ControllerAccountConfirmationInteractor: AccountFetching {
    weak var presenter: ControllerAccountConfirmationInteractorOutputProtocol!

    let selectedAccount: ChainAccountResponse
    let controllerAccountItem: ChainAccountResponse
    let chainAsset: ChainAsset
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let accountRepositoryFactory: AccountRepositoryFactoryProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let signingWrapper: SigningWrapperProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol
    let operationManager: OperationManagerProtocol

    private lazy var callFactory = SubstrateCallFactory()
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var priceProvider: StreamableProvider<PriceData>?
    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var extrinsicService: ExtrinsicServiceProtocol?

    init(
        selectedAccount: ChainAccountResponse,
        controllerAccountItem: ChainAccountResponse,
        chainAsset: ChainAsset,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        accountRepositoryFactory: AccountRepositoryFactoryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        signingWrapper: SigningWrapperProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        operationManager: OperationManagerProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.controllerAccountItem = controllerAccountItem
        self.chainAsset = chainAsset
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.runtimeService = runtimeService
        self.connection = connection
        self.accountRepositoryFactory = accountRepositoryFactory
        self.feeProxy = feeProxy
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.signingWrapper = signingWrapper
        self.storageRequestFactory = storageRequestFactory
        self.operationManager = operationManager
        self.currencyManager = currencyManager
    }

    private func createLedgerFetchOperation(_ accountId: AccountId) -> CompoundOperationWrapper<StakingLedger?> {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<StakingLedger>]> = storageRequestFactory.queryItems(
            engine: connection,
            keyParams: { [accountId] },
            factory: { try coderFactoryOperation.extractNoCancellableResultData() },
            storagePath: Staking.stakingLedger
        )

        let mapOperation = ClosureOperation<StakingLedger?> {
            try wrapper.targetOperation.extractNoCancellableResultData().first?.value
        }

        wrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }

        let dependencies = [coderFactoryOperation] + wrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    private func createBuilderClosure(
        for coderFactory: RuntimeCoderFactoryProtocol
    ) -> ExtrinsicBuilderClosure {
        let controller = controllerAccountItem.accountId

        return { builder in
            let appendCallClosure = try Staking.SetController.appendCall(
                for: .accoundId(controller),
                codingFactory: coderFactory
            )

            return try appendCallClosure(builder)
        }
    }
}

extension ControllerAccountConfirmationInteractor: ControllerAccountConfirmationInteractorInputProtocol {
    func setup() {
        if let address = selectedAccount.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address, chainId: chainAsset.chain.chainId)
        } else {
            presenter.didReceiveStashItem(result: .failure(ChainAccountFetchingError.accountNotExists))
        }

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter.didReceivePriceData(result: .success(nil))
        }

        estimateFee()
        feeProxy.delegate = self
    }

    func confirm() {
        runtimeService.fetchCoderFactory(
            runningIn: operationManager,
            completion: { [weak self] coderFactory in
                guard
                    let signingWrapper = self?.signingWrapper,
                    let builderClosure = self?.createBuilderClosure(for: coderFactory) else {
                    return
                }

                self?.extrinsicService?.submit(
                    builderClosure,
                    signer: signingWrapper,
                    runningIn: .main,
                    completion: { [weak self] result in
                        self?.presenter.didConfirmed(result: result)
                    }
                )
            }, errorClosure: { [weak self] error in
                self?.presenter.didConfirmed(result: .failure(error))
            }
        )
    }

    func estimateFee() {
        runtimeService.fetchCoderFactory(
            runningIn: operationManager,
            completion: { [weak self] coderFactory in
                guard
                    let extrinsicService = self?.extrinsicService,
                    let builderClosure = self?.createBuilderClosure(for: coderFactory),
                    let accountAddress = self?.controllerAccountItem.toAddress() else {
                    return
                }

                let identifier = Staking.SetController.path.callName + accountAddress

                self?.feeProxy.estimateFee(
                    using: extrinsicService,
                    reuseIdentifier: identifier,
                    setupBy: builderClosure
                )
            }, errorClosure: { [weak self] error in
                self?.presenter.didReceiveFee(result: .failure(error))
            }
        )
    }

    func fetchLedger() {
        let accountId = controllerAccountItem.accountId

        let ledgerOperataion = createLedgerFetchOperation(accountId)
        ledgerOperataion.targetOperation.completionBlock = { [weak presenter] in
            DispatchQueue.main.async {
                do {
                    let ledger = try ledgerOperataion.targetOperation.extractNoCancellableResultData()
                    presenter?.didReceiveStakingLedger(result: .success(ledger))
                } catch {
                    presenter?.didReceiveStakingLedger(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(
            operations: ledgerOperataion.allOperations,
            in: .transient
        )
    }
}

extension ControllerAccountConfirmationInteractor: StakingLocalStorageSubscriber,
    StakingLocalSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            clear(streamableProvider: &balanceProvider)

            let maybeStashItem = try result.get()
            let maybeStashId = try maybeStashItem?.stash.toAccountId()

            presenter.didReceiveStashItem(result: .success(maybeStashItem))

            if let stashId = maybeStashId {
                balanceProvider = subscribeToAssetBalanceProvider(
                    for: stashId,
                    chainId: chainAsset.chain.chainId,
                    assetId: chainAsset.asset.assetId
                )

                let chain = chainAsset.chain

                fetchFirstMetaAccountResponse(
                    for: stashId,
                    accountRequest: chainAsset.chain.accountRequest(),
                    repositoryFactory: accountRepositoryFactory,
                    operationManager: operationManager
                ) { [weak self] result in
                    switch result {
                    case let .success(maybeAccountResponse):
                        if let accountResponse = maybeAccountResponse {
                            self?.extrinsicService = self?.extrinsicServiceFactory.createService(
                                account: accountResponse.chainAccount,
                                chain: chain
                            )

                            self?.estimateFee()
                        }
                        self?.presenter.didReceiveStashAccount(result: .success(maybeAccountResponse))
                    case let .failure(error):
                        self?.presenter.didReceiveStashAccount(result: .failure(error))
                    }
                }
            }
        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
        }
    }
}

extension ControllerAccountConfirmationInteractor: PriceLocalStorageSubscriber,
    PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension ControllerAccountConfirmationInteractor: WalletLocalStorageSubscriber,
    WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        presenter.didReceiveAccountBalance(result: result)
    }
}

extension ControllerAccountConfirmationInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        presenter.didReceiveFee(result: result)
    }
}

extension ControllerAccountConfirmationInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
