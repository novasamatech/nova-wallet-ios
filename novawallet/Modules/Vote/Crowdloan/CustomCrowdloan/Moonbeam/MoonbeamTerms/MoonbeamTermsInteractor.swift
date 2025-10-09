import UIKit
import BigInt
import Operation_iOS
import SubstrateSdk

final class MoonbeamTermsInteractor: RuntimeConstantFetching {
    weak var presenter: MoonbeamTermsInteractorOutputProtocol!
    let accountId: AccountId
    let chainId: ChainModel.Id
    let paraId: ParaId
    let asset: AssetModel
    let extrinsicService: ExtrinsicServiceProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let callFactory: SubstrateCallFactoryProtocol
    let moonbeamService: MoonbeamBonusServiceProtocol
    let operationQueue: OperationQueue
    let signingWrapper: SigningWrapperProtocol
    let chainConnection: ChainConnection
    let logger: LoggerProtocol?

    private var priceProvider: StreamableProvider<PriceData>?
    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var subscriptionId: UInt16?

    init(
        accountId: AccountId,
        paraId: ParaId,
        chainId: ChainModel.Id,
        asset: AssetModel,
        extrinsicService: ExtrinsicServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        callFactory: SubstrateCallFactoryProtocol,
        moonbeamService: MoonbeamBonusServiceProtocol,
        operationQueue: OperationQueue,
        signingWrapper: SigningWrapperProtocol,
        chainConnection: ChainConnection,
        currencyManager: CurrencyManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.accountId = accountId
        self.paraId = paraId
        self.chainId = chainId
        self.asset = asset
        self.extrinsicService = extrinsicService
        self.runtimeService = runtimeService
        self.feeProxy = feeProxy
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.callFactory = callFactory
        self.moonbeamService = moonbeamService
        self.operationQueue = operationQueue
        self.signingWrapper = signingWrapper
        self.chainConnection = chainConnection
        self.logger = logger
        self.currencyManager = currencyManager
    }

    private func subscribeToPrice() {
        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter.didReceivePriceData(result: .success(nil))
        }
    }

    private func submitRemarkToChain(_ remark: String) {
        guard let data = remark.data(using: .utf8) else { return }
        let call = callFactory.remark(remark: data)

        let builderClosure: ExtrinsicBuilderClosure = { builder in
            try builder.adding(call: call)
        }

        extrinsicService.buildExtrinsic(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] extrinsicParamsResult in
                switch extrinsicParamsResult {
                case let .success(submittedModel):
                    self?.subscribeToRemarkUpdates(extrinsic: submittedModel.extrinsic)
                case let .failure(error):
                    self?.presenter.didReceiveVerifyRemark(result: .failure(error))
                }
            }
        )
    }

    private func subscribeToRemarkUpdates(extrinsic: String) {
        guard
            let extrinsicHash = try? Data(hexString: extrinsic),
            let hash = try? StorageHasher.blake256.hash(data: extrinsicHash)
        else { return }
        let hashWithPrefix = hash.toHex(includePrefix: true)

        do {
            let updateClosure: (ExtrinsicSubscriptionUpdate) -> Void = { [weak self] update in
                let status = update.params.result
                if case let .finalized(blockHash) = status {
                    DispatchQueue.main.async {
                        self?.verifyRemark(blockHash: blockHash, extrinsicHash: hashWithPrefix)
                    }
                }
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] error, unsubscribed in
                self?.logger?.error("Unexpected failure after subscription: \(error) \(unsubscribed)")
                DispatchQueue.main.async {
                    self?.presenter.didReceiveVerifyRemark(result: .failure(error))
                }
            }

            subscriptionId = try chainConnection.subscribe(
                RPCMethod.submitAndWatchExtrinsic,
                params: [extrinsic],
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )
        } catch {
            logger?.error("Unexpected chain subscription failure: \(error)")
        }
    }

    private func verifyRemark(blockHash: String, extrinsicHash: String) {
        let verifyOperation = moonbeamService.createVerifyRemarkOperation(
            blockHash: blockHash,
            extrinsicHash: extrinsicHash
        )

        execute(
            operation: verifyOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            self?.presenter.didReceiveVerifyRemark(result: result)
        }
    }
}

extension MoonbeamTermsInteractor: MoonbeamTermsInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self
        estimateFee()
        subscribeToPrice()

        balanceProvider = subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chainId,
            assetId: asset.assetId
        )

        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeService,
            operationQueue: operationQueue
        ) { [weak self] (result: Result<BigUInt, Error>) in
            self?.presenter.didReceiveMinimumBalance(result: result)
        }
    }

    var termsURL: URL {
        moonbeamService.termsURL
    }

    func estimateFee() {
        guard let dummyRemark = String(repeating: "0", count: 64).data(using: .utf8) else { return }
        let call = callFactory.remark(remark: dummyRemark)
        let identifier = dummyRemark.description

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: identifier) { builder in
            try builder.adding(call: call)
        }
    }

    func submitAgreement() {
        let statementOperation = moonbeamService.createStatementFetchOperation()
        let submitOperation = moonbeamService.createAgreeRemarkOperation(dependingOn: statementOperation)

        submitOperation.addDependency(statementOperation)

        let wrapper = CompoundOperationWrapper(
            targetOperation: submitOperation,
            dependencies: [statementOperation]
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(remark):
                self?.submitRemarkToChain(remark)
            case let .failure(error):
                self?.presenter.didReceiveVerifyRemark(result: .failure(error))
            }
        }
    }
}

extension MoonbeamTermsInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        presenter.didReceiveFee(result: result)
    }
}

extension MoonbeamTermsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension MoonbeamTermsInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        presenter.didReceiveBalance(result: result)
    }
}

extension MoonbeamTermsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
