import UIKit
import BigInt

final class MoonbeamTermsInteractor {
    weak var presenter: MoonbeamTermsInteractorOutputProtocol!
    let paraId: ParaId
    let asset: AssetModel
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let callFactory: SubstrateCallFactoryProtocol

    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        paraId: ParaId,
        asset: AssetModel,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.paraId = paraId
        self.asset = asset
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.callFactory = callFactory
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
}

extension MoonbeamTermsInteractor: MoonbeamTermsInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self
        estimateFeeForContribution()
        subscribeToPrice()
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
