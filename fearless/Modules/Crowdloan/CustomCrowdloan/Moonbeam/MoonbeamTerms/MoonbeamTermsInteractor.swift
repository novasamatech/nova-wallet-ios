import UIKit
import BigInt
import RobinHood
import FearlessUtils

final class MoonbeamTermsInteractor {
    weak var presenter: MoonbeamTermsInteractorOutputProtocol!
    let accountId: AccountId
    let chainId: ChainModel.Id
    let paraId: ParaId
    let asset: AssetModel
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let callFactory: SubstrateCallFactoryProtocol
    let moonbeamService: MoonbeamBonusServiceProtocol
    let operationManager: OperationManagerProtocol
    let signingWrapper: SigningWrapperProtocol
    let chainConnection: ChainConnection
    let logger: LoggerProtocol?

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var subscriptionId: UInt16?

    init(
        accountId: AccountId,
        paraId: ParaId,
        chainId: ChainModel.Id,
        asset: AssetModel,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        callFactory: SubstrateCallFactoryProtocol,
        moonbeamService: MoonbeamBonusServiceProtocol,
        operationManager: OperationManagerProtocol,
        signingWrapper: SigningWrapperProtocol,
        chainConnection: ChainConnection,
        logger: LoggerProtocol? = nil
    ) {
        self.accountId = accountId
        self.paraId = paraId
        self.chainId = chainId
        self.asset = asset
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.callFactory = callFactory
        self.moonbeamService = moonbeamService
        self.operationManager = operationManager
        self.signingWrapper = signingWrapper
        self.chainConnection = chainConnection
        self.logger = logger
    }

    private func subscribeToPrice() {
        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
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

        extrinsicService.submitAndWatch(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] extrinsicParamsResult in
                switch extrinsicParamsResult {
                case let .success(extrinsic):
                    self?.subscribeToRemarkUpdates(extrinsic: extrinsic)
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

        verifyOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let verified = try verifyOperation.extractNoCancellableResultData()
                    self?.presenter.didReceiveVerifyRemark(result: .success(verified))
                } catch {
                    self?.presenter.didReceiveVerifyRemark(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: [verifyOperation], in: .transient)
    }
}

extension MoonbeamTermsInteractor: MoonbeamTermsInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self
        estimateFee()
        subscribeToPrice()
        accountInfoProvider = subscribeToAccountInfoProvider(for: accountId, chainId: chainId)
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

        submitOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let remark = try submitOperation.extractNoCancellableResultData()
                    self?.submitRemarkToChain(remark)
                } catch {
                    self?.presenter.didReceiveVerifyRemark(result: .failure(error))
                }
            }
        }
        submitOperation.addDependency(statementOperation)

        operationManager.enqueue(operations: [statementOperation, submitOperation], in: .transient)
    }
}

extension MoonbeamTermsInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}

extension MoonbeamTermsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension MoonbeamTermsInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        presenter.didReceiveAccountInfo(result: result)
    }
}
