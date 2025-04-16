import UIKit
import Keystore_iOS
import Operation_iOS
import NovaCrypto
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
    private var balanceProvider: StreamableProvider<AssetBalance>?
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

    private func provideDeprecationFlag() {
        runtimeService.fetchCoderFactory(
            runningIn: operationManager,
            completion: { [weak self] coderFactory in
                let isDeprecated = Staking.SetController.isDeprecated(for: coderFactory)
                self?.presenter.didReceiveIsDeprecated(result: .success(isDeprecated))
            }, errorClosure: { [weak self] error in
                self?.presenter.didReceiveIsDeprecated(result: .failure(error))
            }
        )
    }

    private func estimateFee(
        for account: ChainAccountResponse,
        coderFactory: RuntimeCoderFactoryProtocol
    ) {
        guard
            let extrinsicService = extrinsicService,
            let address = account.toAddress() else {
            return
        }

        let identifier = Staking.SetController.path.callName + address

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: identifier) { builder in
            let builderClosure = try Staking.SetController.appendCall(
                for: .accoundId(account.accountId),
                codingFactory: coderFactory
            )

            return try builderClosure(builder)
        }
    }
}

extension ControllerAccountInteractor: ControllerAccountInteractorInputProtocol {
    func setup() {
        provideDeprecationFlag()

        if let accountAddress = selectedAccount.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: accountAddress, chainId: chainAsset.chain.chainId)
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
                self?.presenter.didReceiveAccounts(result: .success(responses))
            case let .failure(error):
                self?.presenter.didReceiveAccounts(result: .failure(error))
            }
        }

        feeProxy.delegate = self
    }

    func estimateFee(for account: ChainAccountResponse) {
        runtimeService.fetchCoderFactory(
            runningIn: operationManager,
            completion: { [weak self] coderFactory in
                self?.estimateFee(for: account, coderFactory: coderFactory)
            }, errorClosure: { [weak self] error in
                self?.presenter.didReceiveFee(result: .failure(error))
            }
        )
    }

    func fetchControllerAccountInfo(controllerAddress: AccountAddress) {
        do {
            let accountId = try controllerAddress.toAccountId()

            let accountInfoOperation = createAccountInfoFetchOperation(accountId)
            accountInfoOperation.targetOperation.completionBlock = { [weak presenter] in
                DispatchQueue.main.async {
                    do {
                        let accountInfo = try accountInfoOperation.targetOperation.extractNoCancellableResultData()
                        presenter?.didReceiveControllerAccountInfo(
                            result: .success(accountInfo),
                            address: controllerAddress
                        )
                    } catch {
                        presenter?.didReceiveControllerAccountInfo(result: .failure(error), address: controllerAddress)
                    }
                }
            }
            operationManager.enqueue(operations: accountInfoOperation.allOperations, in: .transient)
        } catch {
            presenter.didReceiveControllerAccountInfo(result: .failure(error), address: controllerAddress)
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

    private func createAccountInfoFetchOperation(
        _ accountId: Data
    ) -> CompoundOperationWrapper<AccountInfo?> {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<AccountInfo>]> = storageRequestFactory.queryItems(
            engine: connection,
            keyParams: { [accountId] },
            factory: { try coderFactoryOperation.extractNoCancellableResultData() },
            storagePath: SystemPallet.accountPath
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
            clear(streamableProvider: &balanceProvider)

            let maybeStashItem = try result.get()
            let maybeStashId = try maybeStashItem?.stash.toAccountId()
            let maybeControllerId = try maybeStashItem?.controller.toAccountId()

            presenter.didReceiveStashItem(result: .success(maybeStashItem))

            if let stashId = maybeStashId, let controllerId = maybeControllerId {
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
                    case let .success(accountResponse):
                        let maybeAccount = accountResponse?.chainAccount

                        if let accountResponse = accountResponse, let account = maybeAccount {
                            self?.extrinsicService = self?.extrinsicServiceFactory.createService(
                                account: accountResponse.chainAccount,
                                chain: chain
                            )
                            self?.estimateFee(for: account)
                        }
                        self?.presenter.didReceiveStashAccount(result: .success(accountResponse))
                    case let .failure(error):
                        self?.presenter.didReceiveStashAccount(result: .failure(error))
                    }
                }

                fetchFirstMetaAccountResponse(
                    for: controllerId,
                    accountRequest: chainAsset.chain.accountRequest(),
                    repositoryFactory: accountRepositoryFactory,
                    operationManager: operationManager
                ) { [weak self] result in
                    if case let .success(maybeController) = result, let controller = maybeController {
                        self?.estimateFee(for: controller.chainAccount)
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
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        guard let address = try? accountId.toAddress(using: chainAsset.chain.chainFormat) else {
            return
        }

        presenter.didReceiveAccountBalance(result: result, address: address)
    }
}

extension ControllerAccountInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
