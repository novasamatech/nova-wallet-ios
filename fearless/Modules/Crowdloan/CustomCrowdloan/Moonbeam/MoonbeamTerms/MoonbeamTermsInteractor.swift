import UIKit
import BigInt
import RobinHood

final class MoonbeamTermsInteractor {
    weak var presenter: MoonbeamTermsInteractorOutputProtocol!
    let paraId: ParaId
    let asset: AssetModel
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let callFactory: SubstrateCallFactoryProtocol
    let moonbeamService: MoonbeamBonusServiceProtocol
    let operationManager: OperationManagerProtocol

    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        paraId: ParaId,
        asset: AssetModel,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        callFactory: SubstrateCallFactoryProtocol,
        moonbeamService: MoonbeamBonusServiceProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.paraId = paraId
        self.asset = asset
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.callFactory = callFactory
        self.moonbeamService = moonbeamService
        self.operationManager = operationManager
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
        print(remark)
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
