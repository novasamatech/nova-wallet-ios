import UIKit
import SoraKeystore
import RobinHood
import IrohaCrypto
import SubstrateSdk

final class ControllerAccountInteractor: AccountFetching {
    weak var presenter: ControllerAccountInteractorOutputProtocol!

    let selectedAccount: ChainAccountResponse
    let chainAsset: ChainAsset
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let accountRepositoryFactory: AccountRepositoryFactoryProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol
    let operationManager: OperationManagerProtocol

    private lazy var callFactory = SubstrateCallFactory()
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var extrinsicService: ExtrinsicServiceProtocol?

    init(
        selectedAccount: ChainAccountResponse,
        chainAsset: ChainAsset,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        accountRepositoryFactory: AccountRepositoryFactoryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.runtimeService = runtimeService
        self.connection = connection
        self.accountRepositoryFactory = accountRepositoryFactory
        self.feeProxy = feeProxy
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.storageRequestFactory = storageRequestFactory
        self.operationManager = operationManager
    }
}

extension ControllerAccountInteractor: ControllerAccountInteractorInputProtocol {
    func setup() {
        if let accountAddress = selectedAccount.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: accountAddress)
        } else {
            presenter.didReceiveStashItem(result: .failure(ChainAccountFetchingError.accountNotExists))
        }

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

        feeProxy.delegate = self
    }

    func estimateFee(for account: AccountItem) {
        guard let extrinsicService = extrinsicService else { return }
        do {
            let setController = try callFactory.setController(account.address)
            let identifier = setController.callName + account.identifier

            feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: identifier) { builder in
                try builder.adding(call: setController)
            }
        } catch {
            presenter.didReceiveFee(result: .failure(error))
        }
    }

    func fetchControllerAccountInfo(controllerAddress: AccountAddress) {
        do {
            let accountId = try controllerAddress.toAccountId()

            let accountInfoOperation = createAccountInfoFetchOperation(accountId)
            accountInfoOperation.targetOperation.completionBlock = { [weak presenter] in
                DispatchQueue.main.async {
                    do {
                        let accountInfo = try accountInfoOperation.targetOperation.extractNoCancellableResultData()
                        presenter?.didReceiveAccountInfo(result: .success(accountInfo), address: controllerAddress)
                    } catch {
                        presenter?.didReceiveAccountInfo(result: .failure(error), address: controllerAddress)
                    }
                }
            }
            operationManager.enqueue(operations: accountInfoOperation.allOperations, in: .transient)
        } catch {
            presenter.didReceiveAccountInfo(result: .failure(error), address: controllerAddress)
        }
    }

    func fetchLedger(controllerAddress: AccountAddress) {
        do {
            let accountId = try controllerAddress.toAccountId()

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

    private func createAccountInfoFetchOperation(
        _ accountId: Data
    ) -> CompoundOperationWrapper<AccountInfo?> {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<AccountInfo>]> = storageRequestFactory.queryItems(
            engine: connection,
            keyParams: { [accountId] },
            factory: { try coderFactoryOperation.extractNoCancellableResultData() },
            storagePath: .account
        )

        let mapOperation = ClosureOperation<AccountInfo?> {
            try wrapper.targetOperation.extractNoCancellableResultData().first?.value
        }

        wrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }

        let dependencies = [coderFactoryOperation] + wrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}

extension ControllerAccountInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            clear(dataProvider: &accountInfoProvider)

            let maybeStashItem = try result.get()
            let maybeStashId = try maybeStashItem?.stash.toAccountId()
            let maybeControllerId = try maybeStashItem?.controller.toAccountId()

            presenter.didReceiveStashItem(result: .success(maybeStashItem))

            if let stashId = maybeStashId, let controllerId = maybeControllerId {
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
                    case let .success(accountResponse):
                        let maybeAccountItem = try? accountResponse?.chainAccount.toAccountItem()

                        if let accountResponse = accountResponse, let accountItem = maybeAccountItem {
                            self?.extrinsicService = self?.extrinsicServiceFactory.createService(
                                accountId: accountResponse.chainAccount.accountId,
                                chainFormat: accountResponse.chainAccount.chainFormat,
                                cryptoType: accountResponse.chainAccount.cryptoType
                            )
                            self?.estimateFee(for: accountItem)
                        }
                        self?.presenter.didReceiveStashAccount(result: .success(maybeAccountItem))
                    case let .failure(error):
                        self?.presenter.didReceiveStashAccount(result: .failure(error))
                    }
                }

                fetchFirstAccount(
                    for: controllerId,
                    accountRequest: chainAsset.chain.accountRequest(),
                    repositoryFactory: accountRepositoryFactory,
                    operationManager: operationManager
                ) { [weak self] result in
                    if case let .success(maybeController) = result, let controller = maybeController {
                        self?.estimateFee(for: controller)
                    }

                    self?.presenter.didReceiveControllerAccount(result: result)
                }
            }
        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
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

extension ControllerAccountInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainId _: ChainModel.Id
    ) {
        guard let address = try? accountId.toAddress(using: chainAsset.chain.chainFormat) else {
            return
        }

        presenter.didReceiveAccountInfo(result: result, address: address)
    }
}

extension ControllerAccountInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
