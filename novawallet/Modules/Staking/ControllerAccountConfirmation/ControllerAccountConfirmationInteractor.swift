import UIKit
import RobinHood
import IrohaCrypto
import SubstrateSdk

final class ControllerAccountConfirmationInteractor: AccountFetching {
    weak var presenter: ControllerAccountConfirmationInteractorOutputProtocol!

    let selectedAccount: ChainAccountResponse
    let controllerAccountItem: AccountItem
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
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var extrinsicService: ExtrinsicServiceProtocol?

    init(
        selectedAccount: ChainAccountResponse,
        controllerAccountItem: AccountItem,
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
        operationManager: OperationManagerProtocol
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
    }

    private func createLedgerFetchOperation(_ accountId: AccountId) -> CompoundOperationWrapper<StakingLedger?> {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<StakingLedger>]> = storageRequestFactory.queryItems(
            engine: connection,
            keyParams: { [accountId] },
            factory: { try coderFactoryOperation.extractNoCancellableResultData() },
            storagePath: .stakingLedger
        )

        let mapOperation = ClosureOperation<StakingLedger?> {
            try wrapper.targetOperation.extractNoCancellableResultData().first?.value
        }

        wrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }

        let dependencies = [coderFactoryOperation] + wrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}

extension ControllerAccountConfirmationInteractor: ControllerAccountConfirmationInteractorInputProtocol {
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

        estimateFee()
        feeProxy.delegate = self
    }

    func confirm() {
        do {
            let setController = try callFactory.setController(controllerAccountItem.address)

            extrinsicService?.submit(
                { builder in
                    try builder.adding(call: setController)
                },
                signer: signingWrapper,
                runningIn: .main,
                completion: { [weak self] result in
                    self?.presenter.didConfirmed(result: result)
                }
            )
        } catch {
            presenter.didConfirmed(result: .failure(error))
        }
    }

    func fetchStashAccountItem(for address: AccountAddress) {
        do {
            let stashId = try address.toAccountId()

            fetchFirstMetaAccountResponse(
                for: stashId,
                accountRequest: chainAsset.chain.accountRequest(),
                repositoryFactory: accountRepositoryFactory,
                operationManager: operationManager
            ) { [weak self] result in
                switch result {
                case let .success(accountResponse):
                    let maybeAccountItem = try? accountResponse?.chainAccount.toAccountItem()

                    self?.presenter.didReceiveStashAccount(result: .success(maybeAccountItem))
                case let .failure(error):
                    self?.presenter.didReceiveStashAccount(result: .failure(error))
                }
            }
        } catch {
            presenter.didReceiveStashAccount(result: .failure(error))
        }
    }

    func estimateFee() {
        guard let extrinsicService = extrinsicService else { return }
        do {
            let setController = try callFactory.setController(controllerAccountItem.address)
            let identifier = setController.callName + controllerAccountItem.identifier

            feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: identifier) { builder in
                try builder.adding(call: setController)
            }
        } catch {
            presenter.didReceiveFee(result: .failure(error))
        }
    }

    func fetchLedger() {
        do {
            let accountId = try controllerAccountItem.address.toAccountId()

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
        } catch {
            presenter.didReceiveStakingLedger(result: .failure(error))
        }
    }
}

extension ControllerAccountConfirmationInteractor: StakingLocalStorageSubscriber,
    StakingLocalSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            clear(dataProvider: &accountInfoProvider)

            let maybeStashItem = try result.get()
            let maybeStashId = try maybeStashItem?.stash.toAccountId()

            presenter.didReceiveStashItem(result: .success(maybeStashItem))

            if let stashId = maybeStashId {
                accountInfoProvider = subscribeToAccountInfoProvider(
                    for: stashId,
                    chainId: chainAsset.chain.chainId
                )

                fetchFirstMetaAccountResponse(
                    for: stashId,
                    accountRequest: chainAsset.chain.accountRequest(),
                    repositoryFactory: accountRepositoryFactory,
                    operationManager: operationManager
                ) { [weak self] result in
                    switch result {
                    case let .success(maybeAccountResponse):
                        let maybeAccountItem = try? maybeAccountResponse?.chainAccount.toAccountItem()

                        if let accountResponse = maybeAccountResponse {
                            self?.extrinsicService = self?.extrinsicServiceFactory.createService(
                                accountId: accountResponse.chainAccount.accountId,
                                chainFormat: accountResponse.chainAccount.chainFormat,
                                cryptoType: accountResponse.chainAccount.cryptoType
                            )

                            self?.estimateFee()
                        }
                        self?.presenter.didReceiveStashAccount(result: .success(maybeAccountItem))
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
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension ControllerAccountConfirmationInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
