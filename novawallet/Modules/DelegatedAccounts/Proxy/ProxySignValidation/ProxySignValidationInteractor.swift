import UIKit
import SubstrateSdk

final class ProxySignValidationInteractor {
    weak var presenter: ProxySignValidationInteractorOutputProtocol?

    let selectedAccount: MetaChainAccountResponse
    let extrinsicService: ExtrinsicServiceProtocol
    let runtimeProvider: RuntimeProviderProtocol
    let assetInfoOperationFactory: AssetStorageInfoOperationFactoryProtocol
    let balanceQueryFactory: WalletRemoteQueryWrapperFactoryProtocol
    let calls: [JSON]
    let operationQueue: OperationQueue
    let chainAsset: ChainAsset

    private var existentialDepositCall = CancellableCallStore()
    private var balanceQueryCall = CancellableCallStore()

    init(
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        extrinsicService: ExtrinsicServiceProtocol,
        runtimeProvider: RuntimeProviderProtocol,
        balanceQueryFactory: WalletRemoteQueryWrapperFactoryProtocol,
        assetInfoOperationFactory: AssetStorageInfoOperationFactoryProtocol,
        calls: [JSON],
        operationQueue: OperationQueue
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.extrinsicService = extrinsicService
        self.balanceQueryFactory = balanceQueryFactory
        self.runtimeProvider = runtimeProvider
        self.assetInfoOperationFactory = assetInfoOperationFactory
        self.calls = calls
        self.operationQueue = operationQueue
    }

    deinit {
        existentialDepositCall.cancel()
        balanceQueryCall.cancel()
    }

    private func provideBalance() {
        let wrapper = balanceQueryFactory.queryBalance(
            for: selectedAccount.chainAccount.accountId,
            chainAsset: chainAsset
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: balanceQueryCall,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(balance):
                self?.presenter?.didReceiveBalance(balance)
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }

    private func provideBalanceExistense() {
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

    private func provideFee(for calls: [JSON], codingFactory: RuntimeCoderFactoryProtocol) {
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
}

extension ProxySignValidationInteractor: ProxySignValidationInteractorInputProtocol {
    func setup() {
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
