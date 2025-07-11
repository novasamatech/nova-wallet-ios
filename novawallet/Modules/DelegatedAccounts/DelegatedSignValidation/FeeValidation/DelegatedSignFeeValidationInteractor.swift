import UIKit
import SubstrateSdk

final class DSFeeValidationInteractor {
    weak var presenter: DSFeeValidationInteractorOutputProtocol?

    let selectedAccount: MetaChainAccountResponse
    let extrinsicService: ExtrinsicServiceProtocol
    let runtimeProvider: RuntimeProviderProtocol
    let assetInfoOperationFactory: AssetStorageInfoOperationFactoryProtocol
    let balanceQueryFactory: WalletRemoteQueryWrapperFactoryProtocol
    let validationSharedData: DelegatedSignValidationSharedData
    let call: AnyRuntimeCall
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
        call: AnyRuntimeCall,
        validationSharedData: DelegatedSignValidationSharedData,
        operationQueue: OperationQueue
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.extrinsicService = extrinsicService
        self.balanceQueryFactory = balanceQueryFactory
        self.runtimeProvider = runtimeProvider
        self.assetInfoOperationFactory = assetInfoOperationFactory
        self.call = call
        self.validationSharedData = validationSharedData
        self.operationQueue = operationQueue
    }

    deinit {
        existentialDepositCall.cancel()
        balanceQueryCall.cancel()
    }

    private func provideBalance() {
        let accountId = selectedAccount.chainAccount.accountId

        if let balance = validationSharedData.accounts.fetchValue(for: accountId) {
            presenter?.didReceiveBalance(balance)
            return
        }

        let wrapper = balanceQueryFactory.queryBalance(
            for: accountId,
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

    private func provideFee(for runtimeCall: AnyRuntimeCall) {
        let extrinsicClosure: ExtrinsicBuilderClosure = { builder in
            try builder.adding(call: runtimeCall)
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

extension DSFeeValidationInteractor: DSFeeValidationInteractorInputProtocol {
    func setup() {
        provideBalanceExistense()
        provideBalance()

        provideFee(for: call)
    }

    func updateDataForNextValidation(
        balance: AssetBalance,
        fee: ExtrinsicFeeProtocol?
    ) {
        validationSharedData.accounts.store(
            value: balance,
            for: selectedAccount.chainAccount.accountId
        )

        validationSharedData.paidFee = fee
    }
}
