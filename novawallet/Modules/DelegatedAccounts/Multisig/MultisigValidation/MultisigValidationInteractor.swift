import Foundation
import SubstrateSdk
import Operation_iOS
import BigInt

enum MultisigValidationMode {
    case rootSigner(signer: MetaChainAccountResponse)
    case delegatedSigner(signer: MetaChainAccountResponse, delegate: MetaChainAccountResponse)

    var accountIds: [AccountId] {
        switch self {
        case let .rootSigner(signer):
            return [signer.chainAccount.accountId]
        case let .delegatedSigner(signer, delegate):
            return [signer.chainAccount.accountId, delegate.chainAccount.accountId]
        }
    }

    func matchesBalances(_ balances: [AccountId: AssetBalance]) -> Bool {
        accountIds.allSatisfy { balances[$0] != nil }
    }
}

final class MultisigValidationInteractor: RuntimeConstantFetching {
    weak var presenter: MultisigValidationInteractorOutputProtocol?

    private let validationMode: MultisigValidationMode
    private let multisigContext: DelegatedAccount.MultisigAccountModel

    private let extrinsicService: ExtrinsicServiceProtocol
    private let runtimeProvider: RuntimeProviderProtocol
    private let assetInfoOperationFactory: AssetStorageInfoOperationFactoryProtocol
    private let balanceQueryFactory: WalletRemoteQueryWrapperFactoryProtocol
    private let calls: [JSON]
    private let operationQueue: OperationQueue
    private let chainAsset: ChainAsset

    private var depositCalculator = MultisigDepositCalculator()

    private var existentialDepositCall = CancellableCallStore()
    private var balanceQueryCall = CancellableCallStore()

    init(
        validationMode: MultisigValidationMode,
        multisigContext: DelegatedAccount.MultisigAccountModel,
        extrinsicService: ExtrinsicServiceProtocol,
        runtimeProvider: RuntimeProviderProtocol,
        assetInfoOperationFactory: AssetStorageInfoOperationFactoryProtocol,
        balanceQueryFactory: WalletRemoteQueryWrapperFactoryProtocol,
        calls: [JSON],
        operationQueue: OperationQueue,
        chainAsset: ChainAsset
    ) {
        self.validationMode = validationMode
        self.multisigContext = multisigContext
        self.extrinsicService = extrinsicService
        self.runtimeProvider = runtimeProvider
        self.assetInfoOperationFactory = assetInfoOperationFactory
        self.balanceQueryFactory = balanceQueryFactory
        self.calls = calls
        self.operationQueue = operationQueue
        self.chainAsset = chainAsset
    }

    deinit {
        existentialDepositCall.cancel()
        balanceQueryCall.cancel()
    }
}

// MARK: - Private

private extension MultisigValidationInteractor {
    func provideBalanceExistense() {
        let assetInfoWrapper = assetInfoOperationFactory.createAssetBalanceExistenceOperation(
            chainId: chainAsset.chain.chainId,
            asset: chainAsset.asset,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue
        )

        executeCancellable(
            wrapper: assetInfoWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: existentialDepositCall,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(assetBalanceExistence):
                self?.presenter?.didReceiveBalanceExistense(assetBalanceExistence)
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }

    func createBalancesWrapper() -> CompoundOperationWrapper<[AccountId: AssetBalance]> {
        let wrappers: [AccountId: CompoundOperationWrapper<AssetBalance>]
        wrappers = validationMode.accountIds.reduce(into: [:]) { acc, accountId in
            acc[accountId] = balanceQueryFactory.queryBalance(
                for: accountId,
                chainAsset: chainAsset
            )
        }

        let mapOperation = ClosureOperation<[AccountId: AssetBalance]> {
            try wrappers.mapValues { try $0.targetOperation.extractNoCancellableResultData() }
        }

        wrappers.values.forEach { mapOperation.addDependency($0.targetOperation) }

        let dependencies = wrappers.values.flatMap(\.allOperations)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }

    func provideBalance() {
        let wrapper = createBalancesWrapper()

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: balanceQueryCall,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(balances):
                self?.presenter?.didReceiveBalances(balances)
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }

    func provideFee(for calls: [JSON], codingFactory: RuntimeCoderFactoryProtocol) {
        let extrinsicClosure: ExtrinsicBuilderClosure = { builder in
            let context = codingFactory.createRuntimeJsonContext()

            return try calls.reduce(builder) { accumBuilder, call in
                let runtimeCall = try call.map(
                    to: RuntimeCall<JSON>.self,
                    with: context.toRawContext()
                )

                return try accumBuilder.adding(call: runtimeCall)
            }
        }

        extrinsicService.estimateFee(
            extrinsicClosure,
            runningIn: .main,
            completion: { [weak self] result in
                switch result {
                case let .success(fee):
                    self?.presenter?.didReceiveFee(fee)
                case let .failure(error):
                    self?.presenter?.didReceiveError(error)
                }
            }
        )
    }

    func provideDeposit() {
        guard let deposit = depositCalculator.calculate() else {
            return
        }

        presenter?.didReceiveDeposit(deposit)
    }

    func fetchConstants() {
        let operationManager = OperationManager(operationQueue: operationQueue)

        fetchConstant(
            for: MultisigPallet.depositBase,
            runtimeCodingService: runtimeProvider,
            operationManager: operationManager
        ) { [weak self] (result: Result<BigUInt, Error>) in
            switch result {
            case let .success(depositBase):
                self?.depositCalculator.base = depositBase
                self?.provideDeposit()
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }

        fetchConstant(
            for: MultisigPallet.depositFactor,
            runtimeCodingService: runtimeProvider,
            operationManager: operationManager
        ) { [weak self] (result: Result<BigUInt, Error>) in
            switch result {
            case let .success(depositFactor):
                self?.depositCalculator.factor = depositFactor
                self?.provideDeposit()
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }
}

// MARK: - MultisigValidationInteractorInputProtocol

extension MultisigValidationInteractor: MultisigValidationInteractorInputProtocol {
    func setup() {
        depositCalculator.threshold = multisigContext.threshold

        fetchConstants()

        provideBalanceExistense()
        provideBalance()

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        execute(
            operation: codingFactoryOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let calls = self?.calls else {
                return
            }

            switch result {
            case let .success(codingFactory):
                self?.provideFee(for: calls, codingFactory: codingFactory)
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }
}
