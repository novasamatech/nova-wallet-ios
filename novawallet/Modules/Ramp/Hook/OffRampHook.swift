import Foundation
import Operation_iOS

typealias RampHook = PayCardHook
typealias OffRampParams = MercuryoCardParams
typealias OffRampMessageHandling = PayCardMessageHandling

protocol OffRampHookDelegate: AnyObject {
    func didRequestTransfer(from model: PayCardTopupModel)
}

protocol OffRampHookFactoryProtocol {
    func createHooks(
        using params: OffRampParams,
        for delegate: OffRampHookDelegate
    ) -> [RampHook]
}
