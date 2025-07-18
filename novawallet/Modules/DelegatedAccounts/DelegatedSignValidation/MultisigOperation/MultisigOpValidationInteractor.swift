import Foundation
import SubstrateSdk
import Operation_iOS
import BigInt

final class MultisigOpValidationInteractor: RuntimeConstantFetching {
    weak var presenter: MOValidationInteractorOutputProtocol?

    private let chainRegistry: ChainRegistryProtocol
    private let validationNode: DelegatedSignValidationSequence.MultisigOperationNode
    private let validationState: DelegatedSignValidationSharedData
    private let depositOperationFactory: MultisigDepositOperationFactoryProtocol
    private let multisigOperationFactory: MultisigStorageOperationFactoryProtocol
    private let balanceQueryFactory: WalletRemoteQueryWrapperFactoryProtocol
    private let assetInfoOperationFactory: AssetStorageInfoOperationFactoryProtocol
    private let operationQueue: OperationQueue
    private let chainAsset: ChainAsset

    private let depositCallStore = CancellableCallStore()
    private let balanceQueryCallStore = CancellableCallStore()
    private let operationQueryCallStore = CancellableCallStore()
    private let minBalanceCallStore = CancellableCallStore()

    init(
        validationNode: DelegatedSignValidationSequence.MultisigOperationNode,
        validationState: DelegatedSignValidationSharedData,
        chainAsset: ChainAsset,
        chainRegistry: ChainRegistryProtocol,
        assetInfoOperationFactory: AssetStorageInfoOperationFactoryProtocol,
        multisigOperationFactory: MultisigStorageOperationFactoryProtocol,
        depositOperationFactory: MultisigDepositOperationFactoryProtocol,
        balanceQueryFactory: WalletRemoteQueryWrapperFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.validationNode = validationNode
        self.validationState = validationState
        self.chainRegistry = chainRegistry
        self.assetInfoOperationFactory = assetInfoOperationFactory
        self.multisigOperationFactory = multisigOperationFactory
        self.depositOperationFactory = depositOperationFactory
        self.balanceQueryFactory = balanceQueryFactory
        self.chainAsset = chainAsset
        self.operationQueue = operationQueue
    }

    deinit {
        depositCallStore.cancel()
        balanceQueryCallStore.cancel()
        operationQueryCallStore.cancel()
        minBalanceCallStore.cancel()
    }
}

private extension MultisigOpValidationInteractor {
    func provideBalance() {
        if
            let balance = validationState.accounts.fetchValue(
                for: validationNode.signatory.chainAccount.accountId
            ) {
            presenter?.didReceiveSignatoryBalance(balance)
            return
        }

        let wrapper = balanceQueryFactory.queryBalance(
            for: validationNode.signatory.chainAccount.accountId,
            chainAsset: chainAsset
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: balanceQueryCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(balance):
                self?.presenter?.didReceiveSignatoryBalance(balance)
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }

    func provideFee() {
        presenter?.didReceivePaidFee(
            validationState.paidFees.fetchValue(
                for: validationNode.signatory.chainAccount.accountId
            )
        )
    }

    func provideDeposit() {
        let wrapper = depositOperationFactory.depositWrapper(
            for: chainAsset.chain.chainId,
            threshold: validationNode.call.args.threshold
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: depositCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(deposit):
                self?.presenter?.didReceiveDeposit(deposit)
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }

    private func provideBalanceExistense() {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(
                for: chainAsset.chain.chainId
            )

            let assetInfoWrapper = assetInfoOperationFactory.createAssetBalanceExistenceOperation(
                chainId: chainAsset.chain.chainId,
                asset: chainAsset.asset,
                runtimeProvider: runtimeProvider,
                operationQueue: operationQueue
            )

            executeCancellable(
                wrapper: assetInfoWrapper,
                inOperationQueue: operationQueue,
                backingCallIn: minBalanceCallStore,
                runningCallbackIn: .main
            ) { [weak self] result in
                switch result {
                case let .success(assetBalanceExistence):
                    self?.presenter?.didReceiveBalanceExistense(assetBalanceExistence)
                case let .failure(error):
                    self?.presenter?.didReceiveError(error)
                }
            }
        } catch {
            presenter?.didReceiveError(error)
        }
    }

    func provideOperationDefinition() {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(
                for: chainAsset.chain.chainId
            )

            let connection = try chainRegistry.getConnectionOrError(
                for: chainAsset.chain.chainId
            )

            let callEncodingWrapper = runtimeProvider.createEncodingWrapper(
                for: validationNode.call.args.call,
                of: GenericType.call.name
            )

            let fetchDefinitionWrapper = multisigOperationFactory.fetchPendingOperation(
                for: validationNode.multisig.accountId,
                callHashClosure: {
                    try callEncodingWrapper.targetOperation.extractNoCancellableResultData().blake2b32()
                },
                connection: connection,
                runtimeProvider: runtimeProvider
            )

            fetchDefinitionWrapper.addDependency(wrapper: callEncodingWrapper)

            let wrapper = fetchDefinitionWrapper.insertingHead(
                operations: callEncodingWrapper.allOperations
            )

            executeCancellable(
                wrapper: wrapper,
                inOperationQueue: operationQueue,
                backingCallIn: operationQueryCallStore,
                runningCallbackIn: .main
            ) { [weak self] result in
                switch result {
                case let .success(definition):
                    self?.presenter?.didReceiveMultisigDefinition(definition)
                case let .failure(error):
                    self?.presenter?.didReceiveError(error)
                }
            }

        } catch {
            presenter?.didReceiveError(error)
        }
    }
}

extension MultisigOpValidationInteractor: MOValidationInteractorInputProtocol {
    func setup() {
        provideBalance()
        provideDeposit()
        provideFee()
        provideOperationDefinition()
        provideBalanceExistense()
    }

    func reserve(deposit: Balance, balance: AssetBalance) {
        let newBalance = balance.reserving(balance: deposit)
        validationState.accounts.store(
            value: newBalance,
            for: validationNode.signatory.chainAccount.accountId
        )
    }
}
