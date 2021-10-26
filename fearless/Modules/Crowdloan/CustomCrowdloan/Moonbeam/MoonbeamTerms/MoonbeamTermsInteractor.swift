import UIKit
import BigInt
import RobinHood
import FearlessUtils

final class MoonbeamTermsInteractor {
    weak var presenter: MoonbeamTermsInteractorOutputProtocol!
    let chainId: ChainModel.Id
    let paraId: ParaId
    let asset: AssetModel
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let callFactory: SubstrateCallFactoryProtocol
    let moonbeamService: MoonbeamBonusServiceProtocol
    let operationManager: OperationManagerProtocol
    let signingWrapper: SigningWrapperProtocol
    let chainRegistry: ChainRegistryProtocol

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var subscriptionId: UInt16?
    private var chainConnection: ChainConnection?

    init(
        paraId: ParaId,
        chainId: ChainModel.Id,
        asset: AssetModel,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        callFactory: SubstrateCallFactoryProtocol,
        moonbeamService: MoonbeamBonusServiceProtocol,
        operationManager: OperationManagerProtocol,
        signingWrapper: SigningWrapperProtocol,
        chainRegistry: ChainRegistryProtocol
    ) {
        self.paraId = paraId
        self.chainId = chainId
        self.asset = asset
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.callFactory = callFactory
        self.moonbeamService = moonbeamService
        self.operationManager = operationManager
        self.signingWrapper = signingWrapper
        self.chainRegistry = chainRegistry
    }

    private func subscribeToPrice() {
        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        } else {
            presenter.didReceivePriceData(result: .success(nil))
        }
    }

    private func estimateFeeForContribution() {
        let amount = BigUInt(0)
        let call = callFactory.contribute(to: paraId, amount: amount)

        let identifier = String(amount)

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: identifier) { builder in
            try builder.adding(call: call)
        }
    }

    private func submitRemarkToChain(_ remark: String) {
        guard let data = remark.data(using: .utf8) else { return }

        let builderClosure: ExtrinsicBuilderClosure = { builder in
            let call = SubstrateCallFactory().remark(remark: data)
            return try builder.adding(call: call)
        }

        extrinsicService.submitAndWatch(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] extrinsicParamsResult in
                print(extrinsicParamsResult)
                if case let .success(ext) = extrinsicParamsResult {
                    self?.subscribeToRemarkUpdates(extrinsic: ext)
                }
            }
        )
    }

    private func subscribeToRemarkUpdates(extrinsic: String) {
        do {
            guard let connection = chainRegistry.getConnection(for: chainId) else {
                throw ChainRegistryError.connectionUnavailable
            }

            let updateClosure: (String) -> Void = { [weak self] update in
                DispatchQueue.main.async {
                    print(update)
                    self?.presenter?.didReceiveRemark(result: .success(update))
                }
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] error, unsubscribed in
                print("Unexpected failure after subscription: \(error) \(unsubscribed)")
                self?.presenter?.didReceiveRemark(result: .failure(error))
            }
            chainConnection = connection

            subscriptionId = try chainConnection!.subscribe(
                RPCMethod.submitAndWatchExtrinsic,
                params: [extrinsic],
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )
        } catch {
            print("Unexpected chain subscription failure: \(error)")
        }
    }
}

extension MoonbeamTermsInteractor: MoonbeamTermsInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self
        estimateFeeForContribution()
        subscribeToPrice()
    }

    var termsURL: URL {
        moonbeamService.termsURL
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
                    self?.presenter.didReceiveRemark(result: .failure(error))
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
